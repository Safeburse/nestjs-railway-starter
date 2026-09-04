-- Oriva Asset MVP schema (Deliverable B). Replaces the template Note table.
DROP TABLE IF EXISTS "Note" CASCADE;

-- Oriva Asset MVP — PostgreSQL DDL
-- Deliverable B. Source of meaning: doc/Oriva_Asset_Domain_Model.md v1.11
-- Single-firm install (Wealth Asset Management). One organizations row.
-- Thin CIS: funds, official NAV, unit register, subscribe/redeem.
-- CIS funding: FUND_CUSTODIAN (primary) or PORTFOLIO_CASH.
-- Apply on an empty database. Requires PostgreSQL 14+.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

CREATE TYPE organization_status AS ENUM ('PENDING', 'ACTIVE', 'SUSPENDED', 'CLOSED');
CREATE TYPE user_status AS ENUM ('INVITED', 'ACTIVE', 'LOCKED', 'DISABLED');
CREATE TYPE role_lifecycle AS ENUM ('ACTIVE', 'ARCHIVED');
CREATE TYPE client_status AS ENUM ('DRAFT', 'ACTIVE', 'SUSPENDED', 'CLOSED');
CREATE TYPE client_type AS ENUM ('INDIVIDUAL', 'CORPORATE', 'JOINT', 'TRUST', 'OTHER');
CREATE TYPE equity_holding_arrangement AS ENUM ('DIRECT_BROKERAGE', 'NOMINEE_OMNIBUS');
CREATE TYPE kyc_status AS ENUM ('PENDING', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'EXPIRED');
CREATE TYPE kyc_photo_id_type AS ENUM ('DRIVERS_LICENSE', 'NIN', 'PASSPORT', 'VOTERS_CARD');
CREATE TYPE document_type AS ENUM (
  'ID', 'UTILITY_BILL', 'CAC', 'BOARD_RESOLUTION', 'PROOF_OF_ADDRESS', 'KYC_PACK',
  'EMAIL_INDEMNITY', 'TRADE_INSTRUCTION', 'CIS_INSTRUCTION', 'CONTRACT_NOTE', 'OTHER'
);
CREATE TYPE document_status AS ENUM ('UPLOADED', 'VERIFIED', 'REJECTED', 'ARCHIVED');
CREATE TYPE bank_account_status AS ENUM ('ACTIVE', 'INACTIVE');
CREATE TYPE investment_account_status AS ENUM ('PENDING', 'ACTIVE', 'FROZEN', 'CLOSED');
CREATE TYPE portfolio_status AS ENUM ('PENDING', 'ACTIVE', 'FROZEN', 'CLOSED');
CREATE TYPE mandate_status AS ENUM ('DRAFT', 'ACTIVE', 'SUSPENDED', 'SUPERSEDED');
CREATE TYPE mandate_rule_type AS ENUM (
  'MAX_ALLOCATION_PCT', 'MIN_ALLOCATION_PCT', 'ALLOWED_SECURITY_CLASS',
  'FORBIDDEN_SECURITY_CLASS', 'MAX_SINGLE_SECURITY_PCT', 'MAX_ORDER_AMOUNT'
);
CREATE TYPE security_class AS ENUM (
  'CASH', 'TREASURY_BILL', 'GOVERNMENT_BOND', 'EQUITY', 'FIXED_INCOME'
);
CREATE TYPE security_status AS ENUM ('ACTIVE', 'SUSPENDED', 'MATURED', 'DELISTED');
CREATE TYPE quantity_convention AS ENUM ('SHARES', 'FACE_VALUE', 'CURRENCY_UNITS');
CREATE TYPE cis_order_side AS ENUM ('SUBSCRIBE', 'REDEEM');
CREATE TYPE cis_funding_source AS ENUM ('FUND_CUSTODIAN', 'PORTFOLIO_CASH');
CREATE TYPE fund_status AS ENUM ('DRAFT', 'ACTIVE', 'SUSPENDED', 'CLOSED');
CREATE TYPE order_side AS ENUM ('BUY', 'SELL');
CREATE TYPE order_type AS ENUM ('MARKET', 'LIMIT');
CREATE TYPE order_status AS ENUM (
  'DRAFT', 'SUBMITTED', 'PENDING_APPROVAL', 'APPROVED', 'FILLED',
  'COMPLIANCE_FAILED', 'REJECTED', 'CANCELLED'
);
CREATE TYPE callback_outcome AS ENUM ('CONFIRMED', 'FAILED', 'NOT_REACHED');
CREATE TYPE trade_status AS ENUM (
  'RECORDED', 'SETTLEMENT_PENDING', 'SETTLED', 'SETTLEMENT_FAILED', 'REVERSED'
);
CREATE TYPE settlement_status AS ENUM ('PENDING', 'CONFIRMED', 'FAILED', 'EXCEPTION');
CREATE TYPE transaction_type AS ENUM (
  'DEPOSIT', 'WITHDRAWAL', 'BUY', 'SELL', 'DIVIDEND', 'INTEREST',
  'REDEMPTION', 'FEE', 'TRANSFER', 'ADJUSTMENT', 'REVERSAL',
  'CIS_SUBSCRIPTION', 'CIS_REDEMPTION'
);
CREATE TYPE transaction_status AS ENUM (
  'INITIATED', 'VALIDATED', 'PENDING_APPROVAL', 'APPROVED', 'PROCESSING',
  'CONFIRMED', 'POSTED', 'COMPLETED', 'FAILED', 'EXCEPTION', 'REVERSED'
);
CREATE TYPE ledger_account_type AS ENUM ('ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE');
CREATE TYPE ledger_account_role AS ENUM (
  'CASH', 'SETTLEMENTS_RECEIVABLE', 'SETTLEMENTS_PAYABLE',
  'INVESTMENT_TBILLS', 'INVESTMENT_BONDS', 'INVESTMENT_EQUITIES', 'INVESTMENT_FIXED_INCOME',
  'INVESTMENT_CIS',
  'WITHDRAWAL_PAYABLE', 'FEE_PAYABLE', 'CLIENT_CAPITAL', 'RETAINED_EARNINGS',
  'DIVIDEND_INCOME', 'INTEREST_INCOME', 'REALIZED_GAIN', 'REALIZED_LOSS',
  'MANAGEMENT_FEE_EXPENSE', 'TRANSACTION_FEE_EXPENSE', 'WHT_EXPENSE', 'ROUNDING'
);
CREATE TYPE journal_type AS ENUM (
  'DEPOSIT', 'WITHDRAWAL_APPROVAL', 'WITHDRAWAL_PAYMENT',
  'BUY_TRADE', 'BUY_SETTLEMENT', 'SELL_TRADE', 'SELL_SETTLEMENT',
  'DIVIDEND', 'INTEREST', 'REDEMPTION',
  'FEE_ACCRUAL', 'FEE_COLLECTION',
  'TRANSFER_OUT', 'TRANSFER_IN', 'ADJUSTMENT', 'REVERSAL',
  'CIS_SUBSCRIPTION', 'CIS_REDEMPTION'
);
CREATE TYPE journal_status AS ENUM ('POSTED');
CREATE TYPE lot_status AS ENUM ('OPEN', 'CLOSED');
CREATE TYPE lot_settlement_status AS ENUM ('UNSETTLED', 'SETTLED');
CREATE TYPE reservation_purpose AS ENUM ('ORDER_BUY', 'WITHDRAWAL', 'CIS_SUBSCRIBE', 'CIS_REDEEM', 'OTHER');
CREATE TYPE reservation_status AS ENUM ('ACTIVE', 'CONSUMED', 'RELEASED');
CREATE TYPE recognition_basis AS ENUM ('TRADE_DATE');
CREATE TYPE cost_method AS ENUM ('WEIGHTED_AVERAGE');
CREATE TYPE transaction_cost_treatment AS ENUM ('EXPENSE');
CREATE TYPE income_recognition AS ENUM ('RECEIPT');
CREATE TYPE valuation_basis AS ENUM ('FAIR_VALUE');
CREATE TYPE fee_type AS ENUM ('MANAGEMENT', 'TRANSACTION');
CREATE TYPE fee_accrual_status AS ENUM ('ACCRUED', 'COLLECTED', 'REVERSED');
CREATE TYPE fee_rule_status AS ENUM ('ACTIVE', 'INACTIVE');
CREATE TYPE compliance_result AS ENUM ('PASS', 'FAIL', 'NOT_APPLICABLE');
CREATE TYPE breach_status AS ENUM ('OPEN', 'WAIVED', 'RESOLVED');
CREATE TYPE report_type AS ENUM (
  'CLIENT_STATEMENT', 'PORTFOLIO_STATEMENT', 'HOLDINGS',
  'TRANSACTIONS', 'PERFORMANCE', 'FEES', 'AUDIT', 'TRADE_CONFIRMATION',
  'CIS_CONFIRMATION', 'CIS_UNIT_STATEMENT'
);
CREATE TYPE report_status AS ENUM ('QUEUED', 'GENERATED', 'FAILED');
CREATE TYPE report_format AS ENUM ('PDF', 'CSV');
CREATE TYPE performance_period_type AS ENUM ('DAY', 'MTD', 'QTD', 'YTD', 'CUSTOM');
CREATE TYPE ledger_account_lifecycle AS ENUM ('ACTIVE', 'INACTIVE');

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

CREATE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE FUNCTION reject_mutation() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'immutable table: %', TG_TABLE_NAME;
END;
$$;

-- ---------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------

CREATE TABLE organizations (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code                  text NOT NULL UNIQUE,
  legal_name            text NOT NULL,
  display_name          text NOT NULL,
  status                organization_status NOT NULL DEFAULT 'PENDING',
  country               char(2) NOT NULL DEFAULT 'NG',
  timezone              text NOT NULL DEFAULT 'Africa/Lagos',
  slug                  text UNIQUE,
  logo_object_key       text,
  primary_color         text,
  secondary_color       text,
  custom_domain         text UNIQUE,
  email_from_name       text,
  email_from_address    text,
  report_footer         text,
  terminology_json      jsonb,
  notification_settings_json jsonb,
  executing_broker_name text,
  custodian_name        text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid,
  updated_by_user_id    uuid
);

-- One AM per database. A later AM is a new install, not a second row.
CREATE UNIQUE INDEX organizations_singleton ON organizations ((true));

CREATE TABLE users (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  email                 citext NOT NULL UNIQUE,
  password_hash         text,
  full_name             text NOT NULL,
  status                user_status NOT NULL DEFAULT 'INVITED',
  mfa_enabled           boolean NOT NULL DEFAULT false,
  mfa_secret_encrypted  text,
  last_login_at         timestamptz,
  password_changed_at   timestamptz,
  client_id             uuid,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL
);

ALTER TABLE organizations
  ADD CONSTRAINT organizations_created_by_fk
    FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  ADD CONSTRAINT organizations_updated_by_fk
    FOREIGN KEY (updated_by_user_id) REFERENCES users (id) ON DELETE SET NULL;

CREATE TABLE permissions (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code                  text NOT NULL UNIQUE,
  description           text NOT NULL,
  resource              text NOT NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE roles (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  name                  text NOT NULL,
  is_system             boolean NOT NULL DEFAULT false,
  status                role_lifecycle NOT NULL DEFAULT 'ACTIVE',
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX roles_org_code_uk ON roles (organization_id, code);

CREATE TABLE role_permissions (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id               uuid NOT NULL REFERENCES roles (id) ON DELETE CASCADE,
  permission_id         uuid NOT NULL REFERENCES permissions (id) ON DELETE RESTRICT,
  created_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (role_id, permission_id)
);

CREATE TABLE role_assignments (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  role_id               uuid NOT NULL REFERENCES roles (id) ON DELETE RESTRICT,
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX role_assignments_user_role_org_uk
  ON role_assignments (user_id, role_id, organization_id);

CREATE INDEX role_assignments_org_user_idx ON role_assignments (organization_id, user_id);

CREATE TABLE accounting_policies (
  id                            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id               uuid NOT NULL UNIQUE REFERENCES organizations (id) ON DELETE RESTRICT,
  recognition_basis             recognition_basis NOT NULL DEFAULT 'TRADE_DATE',
  cost_method                   cost_method NOT NULL DEFAULT 'WEIGHTED_AVERAGE',
  transaction_cost_treatment    transaction_cost_treatment NOT NULL DEFAULT 'EXPENSE',
  income_recognition            income_recognition NOT NULL DEFAULT 'RECEIPT',
  valuation_basis               valuation_basis NOT NULL DEFAULT 'FAIR_VALUE',
  money_scale                   integer NOT NULL DEFAULT 2,
  unit_cost_scale               integer NOT NULL DEFAULT 8,
  allow_short_selling           boolean NOT NULL DEFAULT false
                                  CHECK (allow_short_selling = false),
  created_at                    timestamptz NOT NULL DEFAULT now(),
  updated_at                    timestamptz NOT NULL DEFAULT now(),
  created_by_user_id            uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id            uuid REFERENCES users (id) ON DELETE SET NULL
);

CREATE TABLE ledger_accounts (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  name                  text NOT NULL,
  type                  ledger_account_type NOT NULL,
  role                  ledger_account_role,
  is_postable           boolean NOT NULL,
  is_system             boolean NOT NULL DEFAULT false,
  normal_debit          boolean NOT NULL,
  parent_id             uuid REFERENCES ledger_accounts (id) ON DELETE RESTRICT,
  status                ledger_account_lifecycle NOT NULL DEFAULT 'ACTIVE',
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (organization_id, code),
  CONSTRAINT ledger_accounts_postable_chk CHECK (
    (is_postable AND role IS NOT NULL) OR (NOT is_postable AND role IS NULL)
  )
);

CREATE UNIQUE INDEX ledger_accounts_role_uk
  ON ledger_accounts (organization_id, role)
  WHERE role IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Clients, accounts, portfolios
-- ---------------------------------------------------------------------------

CREATE TABLE clients (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  type                  client_type NOT NULL,
  status                client_status NOT NULL DEFAULT 'DRAFT',
  legal_name            text NOT NULL,
  display_name          text,
  email                 citext,
  phone                 text,
  country               char(2) NOT NULL DEFAULT 'NG',
  tax_id                text,
  risk_rating           text,
  onboarded_at          date,
  chn                   text,
  notes                 text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (organization_id, code)
);

CREATE UNIQUE INDEX clients_chn_uk
  ON clients (organization_id, chn)
  WHERE chn IS NOT NULL;

ALTER TABLE users
  ADD CONSTRAINT users_client_fk
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL;

CREATE INDEX users_client_idx ON users (client_id) WHERE client_id IS NOT NULL;

ALTER TABLE role_assignments
  ADD CONSTRAINT role_assignments_client_fk
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE RESTRICT;

CREATE TABLE kyc_records (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  status                kyc_status NOT NULL DEFAULT 'PENDING',
  reviewed_by_user_id   uuid REFERENCES users (id) ON DELETE SET NULL,
  reviewed_at           timestamptz,
  expires_on            date,
  bvn_encrypted         text,
  nin_encrypted         text,
  photo_id_type         kyc_photo_id_type,
  id_number_encrypted   text,
  id_country            text,
  pep_flag              boolean NOT NULL DEFAULT false,
  notes                 text,
  rejection_reason      text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT kyc_rejected_reason_chk CHECK (
    status <> 'REJECTED' OR rejection_reason IS NOT NULL
  ),
  CONSTRAINT kyc_photo_id_number_chk CHECK (
    (photo_id_type IS NULL AND id_number_encrypted IS NULL)
    OR (photo_id_type IS NOT NULL AND id_number_encrypted IS NOT NULL)
  )
);

CREATE INDEX kyc_records_client_idx ON kyc_records (client_id, created_at DESC);

CREATE TABLE client_documents (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  type                  document_type NOT NULL,
  status                document_status NOT NULL DEFAULT 'UPLOADED',
  file_name             text NOT NULL,
  object_key            text NOT NULL,
  mime_type             text NOT NULL,
  byte_size             integer NOT NULL CHECK (byte_size > 0),
  sha256                text NOT NULL,
  verified_by_user_id   uuid REFERENCES users (id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL
);

CREATE TABLE client_bank_accounts (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  label                 text NOT NULL,
  bank_name             text NOT NULL,
  bank_code             text,
  account_name          text NOT NULL,
  account_number        text NOT NULL,
  currency              char(3) NOT NULL,
  status                bank_account_status NOT NULL DEFAULT 'ACTIVE',
  is_default            boolean NOT NULL DEFAULT false,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX client_bank_accounts_nuban_uk
  ON client_bank_accounts (organization_id, bank_code, account_number)
  WHERE bank_code IS NOT NULL;
CREATE UNIQUE INDEX client_bank_accounts_default_uk
  ON client_bank_accounts (client_id)
  WHERE is_default AND status = 'ACTIVE';

CREATE TABLE investment_accounts (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  name                  text NOT NULL,
  status                investment_account_status NOT NULL DEFAULT 'PENDING',
  base_currency         char(3) NOT NULL DEFAULT 'NGN',
  opened_on             date,
  closed_on             date,
  external_reference    text,
  equity_holding_arrangement equity_holding_arrangement,
  cscs_sub_account_code text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (organization_id, code),
  CONSTRAINT investment_accounts_closed_on_chk CHECK (
    status <> 'CLOSED' OR closed_on IS NOT NULL
  )
);

CREATE UNIQUE INDEX investment_accounts_direct_cscs_uk
  ON investment_accounts (organization_id, cscs_sub_account_code)
  WHERE equity_holding_arrangement = 'DIRECT_BROKERAGE'
    AND cscs_sub_account_code IS NOT NULL;

CREATE TABLE portfolios (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  name                  text NOT NULL,
  status                portfolio_status NOT NULL DEFAULT 'PENDING',
  base_currency         char(3) NOT NULL DEFAULT 'NGN',
  inception_on          date,
  closed_on             date,
  benchmark_name        text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (organization_id, code)
);

CREATE INDEX portfolios_account_idx ON portfolios (investment_account_id);

CREATE TABLE cash_balances (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL UNIQUE REFERENCES portfolios (id) ON DELETE RESTRICT,
  currency              char(3) NOT NULL,
  total_cash            numeric(18,2) NOT NULL DEFAULT 0 CHECK (total_cash >= 0),
  reserved_cash         numeric(18,2) NOT NULL DEFAULT 0 CHECK (reserved_cash >= 0),
  available_cash        numeric(18,2) NOT NULL DEFAULT 0 CHECK (available_cash >= 0),
  version               integer NOT NULL DEFAULT 1 CHECK (version >= 1),
  as_of                 timestamptz NOT NULL DEFAULT now(),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cash_balances_identity_chk CHECK (
    available_cash = total_cash - reserved_cash
  )
);

CREATE TABLE portfolio_mandates (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  name                  text NOT NULL,
  status                mandate_status NOT NULL DEFAULT 'DRAFT',
  effective_from        date NOT NULL,
  effective_to          date,
  notes                 text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX portfolio_mandates_active_uk
  ON portfolio_mandates (portfolio_id)
  WHERE status = 'ACTIVE';

CREATE TABLE mandate_rules (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  mandate_id            uuid NOT NULL REFERENCES portfolio_mandates (id) ON DELETE CASCADE,
  type                  mandate_rule_type NOT NULL,
  security_class        security_class,
  security_id           uuid,
  value_numeric         numeric(18,6),
  value_text            text,
  is_blocking           boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Securities
-- ---------------------------------------------------------------------------

CREATE TABLE securities (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  name                  text NOT NULL,
  isin                  text,
  ticker                text,
  class                 security_class NOT NULL,
  currency              char(3) NOT NULL,
  quantity_convention   quantity_convention NOT NULL,
  status                security_status NOT NULL DEFAULT 'ACTIVE',
  issuer_name           text,
  maturity_on           date,
  face_value            numeric(28,8),
  coupon_rate           numeric(12,8),
  day_count             text,
  exchange              text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (organization_id, code),
  CONSTRAINT securities_maturity_chk CHECK (
    class NOT IN ('TREASURY_BILL', 'GOVERNMENT_BOND') OR maturity_on IS NOT NULL
  )
);

ALTER TABLE mandate_rules
  ADD CONSTRAINT mandate_rules_security_fk
    FOREIGN KEY (security_id) REFERENCES securities (id) ON DELETE RESTRICT;

CREATE TABLE security_prices (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  security_id           uuid NOT NULL REFERENCES securities (id) ON DELETE RESTRICT,
  price_date            date NOT NULL,
  price                 numeric(28,8) NOT NULL CHECK (price > 0),
  source                text NOT NULL,
  currency              char(3) NOT NULL,
  is_official           boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL
);

CREATE INDEX security_prices_lookup_idx
  ON security_prices (security_id, price_date DESC, created_at DESC);

-- ---------------------------------------------------------------------------
-- CIS funds (thin): official NAV, unit register, subscribe/redeem
-- ---------------------------------------------------------------------------

CREATE TABLE funds (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  name                  text NOT NULL,
  status                fund_status NOT NULL DEFAULT 'DRAFT',
  base_currency         char(3) NOT NULL DEFAULT 'NGN',
  cash_total            numeric(18,2) NOT NULL DEFAULT 0,
  units_outstanding     numeric(28,8) NOT NULL DEFAULT 0,
  version               integer NOT NULL DEFAULT 1,
  inception_on          date,
  closed_on             date,
  custodian_bank_name   text,
  custodian_account_name text,
  custodian_account_number text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (organization_id, code),
  CONSTRAINT funds_cash_chk CHECK (cash_total >= 0 AND units_outstanding >= 0),
  CONSTRAINT funds_closed_on_chk CHECK (
    status <> 'CLOSED' OR closed_on IS NOT NULL
  )
);

CREATE TABLE fund_nav_prices (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  fund_id               uuid NOT NULL REFERENCES funds (id) ON DELETE RESTRICT,
  price_date            date NOT NULL,
  nav_per_unit          numeric(28,8) NOT NULL CHECK (nav_per_unit > 0),
  accrued_interest_per_unit numeric(28,8) NOT NULL DEFAULT 0
    CHECK (accrued_interest_per_unit >= 0),
  source                text NOT NULL,
  is_official           boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL
);

CREATE INDEX fund_nav_prices_lookup_idx
  ON fund_nav_prices (fund_id, price_date DESC, created_at DESC);

CREATE TABLE fund_unit_positions (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  fund_id               uuid NOT NULL REFERENCES funds (id) ON DELETE RESTRICT,
  units_total           numeric(28,8) NOT NULL DEFAULT 0,
  cost_total            numeric(18,2) NOT NULL DEFAULT 0,
  average_unit_cost     numeric(28,8) NOT NULL DEFAULT 0,
  folio_number          text,
  version               integer NOT NULL DEFAULT 1,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (portfolio_id, fund_id),
  CONSTRAINT fund_unit_positions_qty_chk CHECK (units_total >= 0 AND cost_total >= 0)
);

CREATE UNIQUE INDEX fund_unit_positions_folio_uidx
  ON fund_unit_positions (fund_id, folio_number)
  WHERE folio_number IS NOT NULL;

CREATE TABLE fund_orders (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  fund_id               uuid NOT NULL REFERENCES funds (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  side                  cis_order_side NOT NULL,
  funding_source        cis_funding_source NOT NULL DEFAULT 'FUND_CUSTODIAN',
  status                order_status NOT NULL DEFAULT 'DRAFT',
  amount                numeric(18,2),
  units                 numeric(28,8),
  estimated_units       numeric(28,8),
  estimated_proceeds    numeric(18,2),
  nav_price_id          uuid REFERENCES fund_nav_prices (id) ON DELETE RESTRICT,
  nav_per_unit          numeric(28,8),
  units_issued          numeric(28,8),
  proceeds              numeric(18,2),
  custodian_reference   text,
  payment_verified_at   timestamptz,
  payment_verified_by_user_id uuid REFERENCES users (id) ON DELETE RESTRICT,
  instruction_document_id uuid NOT NULL REFERENCES client_documents (id) ON DELETE RESTRICT,
  callback_at           timestamptz,
  callback_by_user_id   uuid REFERENCES users (id) ON DELETE RESTRICT,
  callback_outcome      callback_outcome,
  callback_notes        text,
  submitted_at          timestamptz,
  submitted_by_user_id  uuid REFERENCES users (id) ON DELETE SET NULL,
  approved_at           timestamptz,
  approved_by_user_id   uuid REFERENCES users (id) ON DELETE SET NULL,
  confirmed_at          timestamptz,
  confirmed_by_user_id  uuid REFERENCES users (id) ON DELETE RESTRICT,
  rejected_at           timestamptz,
  rejected_by_user_id   uuid REFERENCES users (id) ON DELETE SET NULL,
  rejection_reason      text,
  cancelled_at          timestamptz,
  cancel_reason         text,
  notes                 text,
  correlation_id        text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (organization_id, code),
  CONSTRAINT fund_orders_subscribe_amt_chk CHECK (
    side <> 'SUBSCRIBE' OR amount IS NOT NULL
  ),
  CONSTRAINT fund_orders_redeem_units_chk CHECK (
    side <> 'REDEEM' OR units IS NOT NULL
  ),
  CONSTRAINT fund_orders_reject_reason_chk CHECK (
    status <> 'REJECTED' OR rejection_reason IS NOT NULL
  ),
  CONSTRAINT fund_orders_callback_chk CHECK (
    callback_outcome IS NULL OR (
      callback_at IS NOT NULL AND callback_by_user_id IS NOT NULL
    )
  ),
  CONSTRAINT fund_orders_custodian_ref_chk CHECK (
    funding_source <> 'FUND_CUSTODIAN'
    OR side <> 'SUBSCRIBE'
    OR custodian_reference IS NOT NULL
  ),
  CONSTRAINT fund_orders_payment_verify_chk CHECK (
    payment_verified_at IS NULL OR payment_verified_by_user_id IS NOT NULL
  )
);

CREATE UNIQUE INDEX fund_orders_custodian_ref_uidx
  ON fund_orders (organization_id, custodian_reference)
  WHERE custodian_reference IS NOT NULL;

CREATE INDEX fund_orders_portfolio_status_idx ON fund_orders (portfolio_id, status);
CREATE INDEX fund_orders_fund_status_idx ON fund_orders (fund_id, status);

-- ---------------------------------------------------------------------------
-- Orders, trades, settlements, transactions
-- ---------------------------------------------------------------------------

CREATE TABLE orders (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  security_id           uuid NOT NULL REFERENCES securities (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  side                  order_side NOT NULL,
  order_type            order_type NOT NULL,
  status                order_status NOT NULL DEFAULT 'DRAFT',
  quantity              numeric(28,8) NOT NULL CHECK (quantity > 0),
  limit_price           numeric(28,8),
  estimated_consideration numeric(18,2) NOT NULL,
  estimated_fees        numeric(18,2) NOT NULL DEFAULT 0,
  estimated_cash_impact numeric(18,2) NOT NULL,
  mandate_snapshot_json jsonb,
  submitted_at          timestamptz,
  submitted_by_user_id  uuid REFERENCES users (id) ON DELETE SET NULL,
  approved_at           timestamptz,
  approved_by_user_id   uuid REFERENCES users (id) ON DELETE SET NULL,
  rejected_at           timestamptz,
  rejected_by_user_id   uuid REFERENCES users (id) ON DELETE SET NULL,
  rejection_reason      text,
  cancelled_at          timestamptz,
  cancel_reason         text,
  notes                 text,
  instruction_document_id uuid NOT NULL REFERENCES client_documents (id) ON DELETE RESTRICT,
  callback_at           timestamptz,
  callback_by_user_id   uuid REFERENCES users (id) ON DELETE RESTRICT,
  callback_outcome      callback_outcome,
  callback_notes        text,
  correlation_id        text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (organization_id, code),
  CONSTRAINT orders_limit_chk CHECK (
    order_type <> 'LIMIT' OR limit_price IS NOT NULL
  ),
  CONSTRAINT orders_reject_reason_chk CHECK (
    status <> 'REJECTED' OR rejection_reason IS NOT NULL
  ),
  CONSTRAINT orders_callback_chk CHECK (
    callback_outcome IS NULL OR (
      callback_at IS NOT NULL AND callback_by_user_id IS NOT NULL
    )
  )
);

CREATE INDEX orders_portfolio_status_idx ON orders (portfolio_id, status);
CREATE INDEX orders_org_created_idx ON orders (organization_id, created_at DESC);

CREATE TABLE trades (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  order_id              uuid NOT NULL UNIQUE REFERENCES orders (id) ON DELETE RESTRICT,
  security_id           uuid NOT NULL REFERENCES securities (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  side                  order_side NOT NULL,
  status                trade_status NOT NULL DEFAULT 'RECORDED',
  trade_date            date NOT NULL,
  quantity              numeric(28,8) NOT NULL CHECK (quantity > 0),
  price                 numeric(28,8) NOT NULL,
  consideration         numeric(18,2) NOT NULL CHECK (consideration >= 0),
  fees                  numeric(18,2) NOT NULL DEFAULT 0 CHECK (fees >= 0),
  net_amount            numeric(18,2) NOT NULL,
  counterparty          text,
  execution_reference   text,
  recorded_by_user_id   uuid NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  recorded_at           timestamptz NOT NULL DEFAULT now(),
  correlation_id        text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, code)
);

CREATE INDEX trades_portfolio_date_idx ON trades (portfolio_id, trade_date);

CREATE TABLE settlements (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  trade_id              uuid NOT NULL UNIQUE REFERENCES trades (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  status                settlement_status NOT NULL DEFAULT 'PENDING',
  settlement_date       date NOT NULL,
  settled_amount        numeric(18,2) NOT NULL,
  confirmed_by_user_id  uuid REFERENCES users (id) ON DELETE SET NULL,
  confirmed_at          timestamptz,
  failure_reason        text,
  notes                 text,
  correlation_id        text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (organization_id, code)
);

CREATE INDEX settlements_pending_idx ON settlements (status) WHERE status = 'PENDING';

CREATE TABLE transactions (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  type                  transaction_type NOT NULL,
  status                transaction_status NOT NULL DEFAULT 'INITIATED',
  value_date            date NOT NULL,
  amount                numeric(18,2) NOT NULL,
  quantity              numeric(28,8),
  security_id           uuid REFERENCES securities (id) ON DELETE RESTRICT,
  order_id              uuid REFERENCES orders (id) ON DELETE RESTRICT,
  trade_id              uuid REFERENCES trades (id) ON DELETE RESTRICT,
  settlement_id         uuid REFERENCES settlements (id) ON DELETE RESTRICT,
  related_transaction_id uuid REFERENCES transactions (id) ON DELETE RESTRICT,
  fee_accrual_id        uuid,
  client_bank_account_id uuid REFERENCES client_bank_accounts (id) ON DELETE RESTRICT,
  external_reference    text,
  reason                text,
  before_state_json     jsonb,
  after_state_json      jsonb,
  gross_amount          numeric(18,2),
  wht_amount            numeric(18,2) NOT NULL DEFAULT 0,
  net_amount            numeric(18,2),
  idempotency_key       text NOT NULL,
  approved_by_user_id   uuid REFERENCES users (id) ON DELETE SET NULL,
  posted_at             timestamptz,
  completed_at          timestamptz,
  failure_code          text,
  notes                 text,
  correlation_id        text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (organization_id, code)
);

CREATE UNIQUE INDEX transactions_deposit_ref_uk
  ON transactions (organization_id, external_reference)
  WHERE type = 'DEPOSIT'
    AND external_reference IS NOT NULL
    AND status NOT IN ('FAILED', 'EXCEPTION');

CREATE INDEX transactions_portfolio_type_status_idx
  ON transactions (portfolio_id, type, status);
CREATE INDEX transactions_related_idx ON transactions (related_transaction_id);

CREATE TABLE ledger_journals (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  transaction_id        uuid NOT NULL REFERENCES transactions (id) ON DELETE RESTRICT,
  trade_id              uuid REFERENCES trades (id) ON DELETE RESTRICT,
  settlement_id         uuid REFERENCES settlements (id) ON DELETE RESTRICT,
  fund_order_id         uuid REFERENCES fund_orders (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  type                  journal_type NOT NULL,
  status                journal_status NOT NULL DEFAULT 'POSTED',
  value_date            date NOT NULL,
  posting_date          date NOT NULL,
  description           text NOT NULL,
  reverses_journal_id   uuid REFERENCES ledger_journals (id) ON DELETE RESTRICT,
  debit_total           numeric(18,2) NOT NULL,
  credit_total          numeric(18,2) NOT NULL,
  correlation_id        text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (organization_id, code),
  UNIQUE (transaction_id, type),
  CONSTRAINT ledger_journals_balanced_chk CHECK (
    debit_total = credit_total AND debit_total > 0
  )
);

CREATE INDEX ledger_journals_portfolio_date_idx
  ON ledger_journals (portfolio_id, value_date);

CREATE TABLE ledger_entries (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  journal_id            uuid NOT NULL REFERENCES ledger_journals (id) ON DELETE CASCADE,
  ledger_account_id     uuid NOT NULL REFERENCES ledger_accounts (id) ON DELETE RESTRICT,
  role                  ledger_account_role NOT NULL,
  debit                 numeric(18,2) NOT NULL DEFAULT 0 CHECK (debit >= 0),
  credit                numeric(18,2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
  amount                numeric(18,2) NOT NULL,
  currency              char(3) NOT NULL,
  security_id           uuid REFERENCES securities (id) ON DELETE RESTRICT,
  fund_id               uuid REFERENCES funds (id) ON DELETE RESTRICT,
  description           text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ledger_entries_side_chk CHECK (
    (debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)
  ),
  CONSTRAINT ledger_entries_amount_chk CHECK (amount = debit + credit),
  CONSTRAINT ledger_entries_instrument_chk CHECK (
    NOT (security_id IS NOT NULL AND fund_id IS NOT NULL)
  )
);

CREATE INDEX ledger_entries_gl_idx ON ledger_entries (portfolio_id, ledger_account_id);
CREATE INDEX ledger_entries_journal_idx ON ledger_entries (journal_id);

CREATE TABLE cash_reservations (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  purpose               reservation_purpose NOT NULL,
  status                reservation_status NOT NULL DEFAULT 'ACTIVE',
  amount                numeric(18,2) NOT NULL CHECK (amount > 0),
  order_id              uuid REFERENCES orders (id) ON DELETE RESTRICT,
  fund_order_id         uuid REFERENCES fund_orders (id) ON DELETE RESTRICT,
  transaction_id        uuid REFERENCES transactions (id) ON DELETE RESTRICT,
  expires_at            timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL
);

CREATE INDEX cash_reservations_active_idx
  ON cash_reservations (portfolio_id)
  WHERE status = 'ACTIVE';

-- ---------------------------------------------------------------------------
-- Positions
-- ---------------------------------------------------------------------------

CREATE TABLE positions (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  security_id           uuid NOT NULL REFERENCES securities (id) ON DELETE RESTRICT,
  quantity_total        numeric(28,8) NOT NULL DEFAULT 0,
  quantity_settled      numeric(28,8) NOT NULL DEFAULT 0 CHECK (quantity_settled >= 0),
  quantity_unsettled    numeric(28,8) NOT NULL DEFAULT 0 CHECK (quantity_unsettled >= 0),
  cost_total            numeric(18,2) NOT NULL DEFAULT 0,
  average_unit_cost     numeric(28,8) NOT NULL DEFAULT 0,
  realized_pnl_life     numeric(18,2) NOT NULL DEFAULT 0,
  version               integer NOT NULL DEFAULT 1 CHECK (version >= 1),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (portfolio_id, security_id),
  CONSTRAINT positions_qty_chk CHECK (
    quantity_total = quantity_settled + quantity_unsettled
  )
);

CREATE INDEX positions_org_security_idx ON positions (organization_id, security_id);

CREATE TABLE position_lots (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  position_id           uuid NOT NULL REFERENCES positions (id) ON DELETE RESTRICT,
  security_id           uuid NOT NULL REFERENCES securities (id) ON DELETE RESTRICT,
  source_trade_id       uuid REFERENCES trades (id) ON DELETE RESTRICT,
  source_transaction_id uuid NOT NULL REFERENCES transactions (id) ON DELETE RESTRICT,
  status                lot_status NOT NULL DEFAULT 'OPEN',
  settlement_status     lot_settlement_status NOT NULL DEFAULT 'UNSETTLED',
  open_date             date NOT NULL,
  quantity_opened       numeric(28,8) NOT NULL,
  quantity_remaining    numeric(28,8) NOT NULL,
  unit_cost             numeric(28,8) NOT NULL,
  cost_remaining        numeric(18,2) NOT NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT position_lots_qty_chk CHECK (
    quantity_remaining >= 0 AND quantity_remaining <= quantity_opened
  )
);

CREATE INDEX position_lots_open_idx ON position_lots (position_id, status);

-- ---------------------------------------------------------------------------
-- Valuation, performance, fees, compliance, reporting, audit
-- ---------------------------------------------------------------------------

CREATE TABLE portfolio_valuations (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  valuation_date        date NOT NULL,
  run_at                timestamptz NOT NULL DEFAULT now(),
  currency              char(3) NOT NULL,
  cash                  numeric(18,2) NOT NULL,
  settlements_receivable numeric(18,2) NOT NULL DEFAULT 0,
  settlements_payable   numeric(18,2) NOT NULL DEFAULT 0,
  withdrawal_payable    numeric(18,2) NOT NULL DEFAULT 0,
  fees_payable          numeric(18,2) NOT NULL DEFAULT 0,
  investments_cost      numeric(18,2) NOT NULL,
  investments_market_value numeric(18,2) NOT NULL,
  unrealized_pnl        numeric(18,2) NOT NULL,
  book_nav              numeric(18,2) NOT NULL,
  market_nav            numeric(18,2) NOT NULL,
  has_stale_prices      boolean NOT NULL DEFAULT false,
  stale_notes           text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (portfolio_id, valuation_date, run_at),
  CONSTRAINT valuations_nav_chk CHECK (market_nav = book_nav + unrealized_pnl)
);

CREATE TABLE portfolio_valuation_lines (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  valuation_id          uuid NOT NULL REFERENCES portfolio_valuations (id) ON DELETE CASCADE,
  security_id           uuid REFERENCES securities (id) ON DELETE RESTRICT,
  fund_id               uuid REFERENCES funds (id) ON DELETE RESTRICT,
  quantity              numeric(28,8) NOT NULL,
  cost                  numeric(18,2) NOT NULL,
  price                 numeric(28,8) NOT NULL,
  price_date            date NOT NULL,
  is_stale              boolean NOT NULL DEFAULT false,
  accrued_interest      numeric(18,2) NOT NULL DEFAULT 0 CHECK (accrued_interest >= 0),
  market_value          numeric(18,2) NOT NULL,
  unrealized_pnl        numeric(18,2) NOT NULL,
  CONSTRAINT valuation_lines_target_chk CHECK (
    (security_id IS NOT NULL AND fund_id IS NULL)
    OR (security_id IS NULL AND fund_id IS NOT NULL)
  )
);

CREATE TABLE performance_records (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  period_type           performance_period_type NOT NULL,
  period_start          date NOT NULL,
  period_end            date NOT NULL,
  begin_market_nav      numeric(18,2) NOT NULL,
  end_market_nav        numeric(18,2) NOT NULL,
  net_flows             numeric(18,2) NOT NULL DEFAULT 0,
  fees                  numeric(18,2) NOT NULL DEFAULT 0,
  realized_pnl          numeric(18,2) NOT NULL DEFAULT 0,
  unrealized_change     numeric(18,2) NOT NULL DEFAULT 0,
  simple_return_pct     numeric(18,8),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (portfolio_id, period_type, period_start, period_end)
);

CREATE TABLE fee_rules (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  portfolio_id          uuid REFERENCES portfolios (id) ON DELETE RESTRICT,
  name                  text NOT NULL,
  type                  fee_type NOT NULL,
  status                fee_rule_status NOT NULL DEFAULT 'ACTIVE',
  accrual_frequency     text,
  rate_bps              numeric(12,4),
  flat_amount           numeric(18,2),
  transaction_rate_bps  numeric(12,4),
  min_amount            numeric(18,2),
  currency              char(3) NOT NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  updated_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL
);

CREATE TABLE fee_accruals (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  fee_rule_id           uuid NOT NULL REFERENCES fee_rules (id) ON DELETE RESTRICT,
  status                fee_accrual_status NOT NULL DEFAULT 'ACCRUED',
  period_start          date NOT NULL,
  period_end            date NOT NULL,
  base_nav              numeric(18,2) NOT NULL,
  amount                numeric(18,2) NOT NULL,
  accrual_transaction_id uuid REFERENCES transactions (id) ON DELETE RESTRICT,
  collection_transaction_id uuid REFERENCES transactions (id) ON DELETE RESTRICT,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE transactions
  ADD CONSTRAINT transactions_fee_accrual_fk
    FOREIGN KEY (fee_accrual_id) REFERENCES fee_accruals (id) ON DELETE RESTRICT;

CREATE INDEX fee_accruals_portfolio_status_idx ON fee_accruals (portfolio_id, status);

CREATE TABLE compliance_checks (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  client_id             uuid NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
  investment_account_id uuid NOT NULL REFERENCES investment_accounts (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  order_id              uuid REFERENCES orders (id) ON DELETE RESTRICT,
  transaction_id        uuid REFERENCES transactions (id) ON DELETE RESTRICT,
  mandate_rule_id       uuid REFERENCES mandate_rules (id) ON DELETE SET NULL,
  rule_code             text NOT NULL,
  result                compliance_result NOT NULL,
  message               text NOT NULL,
  evaluated_at          timestamptz NOT NULL DEFAULT now(),
  details_json          jsonb,
  created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX compliance_checks_order_idx ON compliance_checks (order_id);

CREATE TABLE compliance_breaches (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  portfolio_id          uuid NOT NULL REFERENCES portfolios (id) ON DELETE RESTRICT,
  compliance_check_id   uuid NOT NULL REFERENCES compliance_checks (id) ON DELETE RESTRICT,
  status                breach_status NOT NULL DEFAULT 'OPEN',
  waived_by_user_id     uuid REFERENCES users (id) ON DELETE SET NULL,
  waiver_reason         text,
  resolved_at           timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE reports (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  code                  text NOT NULL,
  type                  report_type NOT NULL,
  format                report_format NOT NULL DEFAULT 'PDF',
  status                report_status NOT NULL DEFAULT 'QUEUED',
  portfolio_id          uuid REFERENCES portfolios (id) ON DELETE RESTRICT,
  client_id             uuid REFERENCES clients (id) ON DELETE RESTRICT,
  period_start          date,
  period_end            date,
  object_key            text,
  parameters_json       jsonb,
  error_message         text,
  generated_at          timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  created_by_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  UNIQUE (organization_id, code)
);

CREATE INDEX reports_org_type_idx ON reports (organization_id, type, created_at DESC);

CREATE TABLE audit_events (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  actor_user_id         uuid REFERENCES users (id) ON DELETE SET NULL,
  occurred_at           timestamptz NOT NULL DEFAULT now(),
  action                text NOT NULL,
  entity_type           text NOT NULL,
  entity_id             uuid NOT NULL,
  previous_state_json   jsonb,
  new_state_json        jsonb,
  reason                text,
  correlation_id        text NOT NULL,
  ip_address            text,
  user_agent            text
);

CREATE INDEX audit_events_org_time_idx ON audit_events (organization_id, occurred_at DESC);
CREATE INDEX audit_events_entity_idx ON audit_events (entity_type, entity_id);

CREATE TABLE idempotency_records (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  key                   text NOT NULL,
  endpoint              text NOT NULL,
  request_hash          text NOT NULL,
  response_code         integer NOT NULL,
  response_body_json    jsonb NOT NULL,
  transaction_id        uuid REFERENCES transactions (id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, key)
);

CREATE TABLE code_sequences (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  entity_key            text NOT NULL,
  period_year           integer,
  last_value            integer NOT NULL DEFAULT 0 CHECK (last_value >= 0)
);

CREATE UNIQUE INDEX code_sequences_uk
  ON code_sequences (organization_id, entity_key, COALESCE(period_year, 0));

-- ---------------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------------

CREATE VIEW v_gl_role_balances AS
SELECT
  e.portfolio_id,
  e.organization_id,
  a.role,
  CASE
    WHEN a.normal_debit THEN SUM(e.debit) - SUM(e.credit)
    ELSE SUM(e.credit) - SUM(e.debit)
  END AS balance
FROM ledger_entries e
JOIN ledger_journals j ON j.id = e.journal_id
JOIN ledger_accounts a ON a.id = e.ledger_account_id
GROUP BY e.portfolio_id, e.organization_id, a.role, a.normal_debit;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

CREATE TRIGGER organizations_updated_at BEFORE UPDATE ON organizations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER roles_updated_at BEFORE UPDATE ON roles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER clients_updated_at BEFORE UPDATE ON clients
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER portfolios_updated_at BEFORE UPDATE ON portfolios
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER cash_balances_updated_at BEFORE UPDATE ON cash_balances
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER funds_updated_at BEFORE UPDATE ON funds
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER fund_unit_positions_updated_at BEFORE UPDATE ON fund_unit_positions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER fund_orders_updated_at BEFORE UPDATE ON fund_orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER orders_updated_at BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trades_updated_at BEFORE UPDATE ON trades
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER settlements_updated_at BEFORE UPDATE ON settlements
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER transactions_updated_at BEFORE UPDATE ON transactions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER positions_updated_at BEFORE UPDATE ON positions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER ledger_journals_immutable
  BEFORE UPDATE OR DELETE ON ledger_journals
  FOR EACH ROW EXECUTE FUNCTION reject_mutation();
CREATE TRIGGER ledger_entries_immutable
  BEFORE UPDATE OR DELETE ON ledger_entries
  FOR EACH ROW EXECUTE FUNCTION reject_mutation();
CREATE TRIGGER audit_events_immutable
  BEFORE UPDATE OR DELETE ON audit_events
  FOR EACH ROW EXECUTE FUNCTION reject_mutation();
