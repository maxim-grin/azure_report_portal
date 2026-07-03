-- scripts/seed.sql

CREATE TABLE expense_reports (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    user_id NVARCHAR(100) NOT NULL,
    title NVARCHAR(200) NOT NULL,
    period NVARCHAR(20) NOT NULL,
    submitted_at DATETIME2 DEFAULT SYSUTCDATETIME(),
    status NVARCHAR(20) DEFAULT 'approved'
);

CREATE TABLE expense_line_items (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    report_id UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES expense_reports(id),
    description NVARCHAR(200) NOT NULL,
    category NVARCHAR(50) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    expense_date DATE NOT NULL
);

-- Seed: one user, one report, five line items
DECLARE @report_id UNIQUEIDENTIFIER = NEWID();

INSERT INTO expense_reports (id, user_id, title, period)
VALUES (@report_id, 'user-001', 'Client visit — Berlin', '2026-06');

INSERT INTO expense_line_items (report_id, description, category, amount, expense_date) VALUES
(@report_id, 'Flight LHR-BER', 'Travel', 184.50, '2026-06-10'),
(@report_id, 'Hotel — 2 nights', 'Accommodation', 240.00, '2026-06-10'),
(@report_id, 'Client dinner', 'Meals', 86.30, '2026-06-11'),
(@report_id, 'Taxi to airport', 'Travel', 32.00, '2026-06-12'),
(@report_id, 'Conference badge', 'Other', 150.00, '2026-06-10');
