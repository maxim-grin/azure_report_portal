"""
HTTP-triggered function: POST /send-report-email
Body: { "report_id": "<uuid>", "download_url": "<sas-url>" }

Separate from generate_report deliberately — if ACS is briefly down,
retry just this step without regenerating the PDF.
"""

import os
import json
import logging

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.communication.email import EmailClient

app = func.FunctionApp()

KEY_VAULT_URI = os.environ["KEY_VAULT_URI"]
ACS_SECRET_NAME = os.environ["ACS_CONNECTION_STRING_SECRET"]
SENDER_ADDRESS = os.environ["ACS_SENDER_ADDRESS"]  # e.g. DoNotReply@<guid>.azurecomm.net

_credential = DefaultAzureCredential()


def _get_acs_connection_string() -> str:
    client = SecretClient(vault_url=KEY_VAULT_URI, credential=_credential)
    return client.get_secret(ACS_SECRET_NAME).value


def _build_email_content(download_url: str, expires_in_hours: int) -> dict:
    return {
        "subject": "Your expense report is ready",
        "plainText": (
            f"Your report is ready to download.\n\n"
            f"Download link (expires in {expires_in_hours}h): {download_url}\n\n"
            f"If you did not request this report, contact support."
        ),
        "html": f"""
            <p>Your report is ready to download.</p>
            <p><a href="{download_url}">Download report</a></p>
            <p style="color:#888;font-size:12px">
                This link expires in {expires_in_hours} hours.
                If you did not request this report, contact support.
            </p>
        """,
    }


@app.function_name(name="send_report_email")
@app.route(route="send-report-email", methods=["POST"], auth_level=func.AuthLevel.ANONYMOUS)
def send_report_email(req: func.HttpRequest) -> func.HttpResponse:
    """
    Same trust model as generate_report — Easy Auth validates the JWT at the platform layer,
    forwards authenticated user context. recipient_email comes from the
    forwarded claim, never from the request body, so a caller can't
    redirect someone else's report to their own inbox.
    """
    recipient_email = req.headers.get("x-ms-client-principal-name")  # email claim
    if not recipient_email:
        return func.HttpResponse(
            json.dumps({"error": "missing authenticated user context"}),
            status_code=401,
            mimetype="application/json",
        )

    try:
        body = req.get_json()
        download_url = body["download_url"]
        expires_in_hours = body.get("expires_in_hours", 48)
    except (KeyError, json.JSONDecodeError):
        return func.HttpResponse(
            json.dumps({"error": "invalid or missing download_url"}),
            status_code=400,
            mimetype="application/json",
        )

    try:
        conn_str = _get_acs_connection_string()
        email_client = EmailClient.from_connection_string(conn_str)

        content = _build_email_content(download_url, expires_in_hours)
        message = {
            "senderAddress": SENDER_ADDRESS,
            "recipients": {"to": [{"address": recipient_email}]},
            "content": {
                "subject": content["subject"],
                "plainText": content["plainText"],
                "html": content["html"],
            },
        }

        poller = email_client.begin_send(message)
        result = poller.result()

    except Exception:
        logging.exception("Email dispatch failed")
        return func.HttpResponse(
            json.dumps({"error": "failed to send email"}),
            status_code=502,
            mimetype="application/json",
        )

    return func.HttpResponse(
        json.dumps({"status": "sent", "message_id": result["id"]}),
        status_code=200,
        mimetype="application/json",
    )
