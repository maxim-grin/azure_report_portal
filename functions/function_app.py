"""
HTTP-triggered function: POST /generate
Body: { "report_id": "<uuid>" }

Flow:
1. Extract user_id from validated JWT claims (Easy Auth already verified the token).
2. Fetch report header + line items from SQL, scoped to that user_id.
3. Build PDF via pdf_builder.
4. Upload PDF to Blob Storage under a non-guessable path.
5. Generate a time-limited SAS URL.
6. Return the URL (caller — or a second function — handles emailing it).
"""

import os
import json
import uuid
import logging
from datetime import datetime, timedelta

import azure.functions as func
import pyodbc
from azure.identity import DefaultAzureCredential
from azure.storage.blob import (
    BlobServiceClient, generate_blob_sas, BlobSasPermissions
)
from azure.keyvault.secrets import SecretClient

from pdf_builder import build_expense_report_pdf

app = func.FunctionApp()

KEY_VAULT_URI = os.environ["KEY_VAULT_URI"]
STORAGE_ACCOUNT_NAME = os.environ["REPORTS_STORAGE_ACCOUNT_NAME"]
CONTAINER_NAME = "reports"
SQL_SECRET_NAME = os.environ["SQL_CONNECTION_STRING_SECRET"]

_credential = DefaultAzureCredential()


def _get_sql_connection_string() -> str:
    client = SecretClient(vault_url=KEY_VAULT_URI, credential=_credential)
    return client.get_secret(SQL_SECRET_NAME).value


def _fetch_report(conn, report_id: str, user_id: str):
    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT id, user_id, title, period, submitted_at, status
        FROM expense_reports
        WHERE id = ? AND user_id = ?
        """,
        report_id, user_id,
    )
    row = cursor.fetchone()
    if row is None:
        return None, []

    report = {
        "id": str(row.id),
        "user_id": row.user_id,
        "title": row.title,
        "period": row.period,
        "submitted_at": row.submitted_at.strftime("%Y-%m-%d"),
        "status": row.status,
    }

    cursor.execute(
        """
        SELECT description, category, amount, expense_date
        FROM expense_line_items
        WHERE report_id = ?
        ORDER BY expense_date
        """,
        report_id,
    )
    line_items = [
        {
            "description": r.description,
            "category": r.category,
            "amount": float(r.amount),
            "expense_date": r.expense_date.strftime("%Y-%m-%d"),
        }
        for r in cursor.fetchall()
    ]

    return report, line_items


def _upload_pdf(pdf_bytes: bytes, user_id: str, report_id: str) -> str:
    account_url = f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
    blob_service = BlobServiceClient(account_url=account_url, credential=_credential)

    # Non-guessable path: user_id + report_id + random UUID component
    blob_name = f"{user_id}/{report_id}/{uuid.uuid4()}.pdf"
    blob_client = blob_service.get_blob_client(container=CONTAINER_NAME, blob=blob_name)
    blob_client.upload_blob(pdf_bytes, overwrite=True)

    # User-delegation SAS — no storage account key needed, ties expiry to managed identity
    delegation_key = blob_service.get_user_delegation_key(
        key_start_time=datetime.utcnow(),
        key_expiry_time=datetime.utcnow() + timedelta(hours=48),
    )
    sas_token = generate_blob_sas(
        account_name=STORAGE_ACCOUNT_NAME,
        container_name=CONTAINER_NAME,
        blob_name=blob_name,
        user_delegation_key=delegation_key,
        permission=BlobSasPermissions(read=True),
        expiry=datetime.utcnow() + timedelta(hours=48),
    )

    return f"{blob_client.url}?{sas_token}"


@app.function_name(name="generate_report")
@app.route(route="generate", methods=["POST"], auth_level=func.AuthLevel.ANONYMOUS)
def generate_report(req: func.HttpRequest) -> func.HttpResponse:
    """
    Auth note: auth_level is ANONYMOUS here because App Service Authentication
    (Easy Auth) validates the Entra ID token at the platform layer before any
    request reaches this code — see auth_settings_v2 in modules/functions.
    The function trusts the x-ms-client-principal-id header the platform sets
    (and overwrites if a caller supplies it), NOT a body parameter —
    this is what prevents one user requesting another user's report.
    """
    user_id = req.headers.get("x-ms-client-principal-id")
    if not user_id:
        return func.HttpResponse(
            json.dumps({"error": "missing authenticated user context"}),
            status_code=401,
            mimetype="application/json",
        )

    try:
        body = req.get_json()
        report_id = body["report_id"]
        uuid.UUID(report_id)  # validates format, raises if malformed
    except (ValueError, KeyError, json.JSONDecodeError):
        return func.HttpResponse(
            json.dumps({"error": "invalid or missing report_id"}),
            status_code=400,
            mimetype="application/json",
        )

    try:
        conn_str = _get_sql_connection_string()
        conn = pyodbc.connect(conn_str)
    except Exception:
        logging.exception("SQL connection failed")
        return func.HttpResponse(
            json.dumps({"error": "internal error"}),
            status_code=500,
            mimetype="application/json",
        )

    report, line_items = _fetch_report(conn, report_id, user_id)
    conn.close()

    if report is None:
        # Same response whether report doesn't exist or belongs to someone else —
        # avoids leaking which report_ids are valid.
        return func.HttpResponse(
            json.dumps({"error": "report not found"}),
            status_code=404,
            mimetype="application/json",
        )

    pdf_bytes = build_expense_report_pdf(report, line_items)
    sas_url = _upload_pdf(pdf_bytes, user_id, report_id)

    return func.HttpResponse(
        json.dumps({"report_id": report_id, "download_url": sas_url, "expires_in_hours": 48}),
        status_code=200,
        mimetype="application/json",
    )
