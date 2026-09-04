import { Module } from "@nestjs/common"

import { HealthModule } from "./health/health.module"
import { PrismaModule } from "./prisma/prisma.module"
import { AuthModule } from "./auth/auth.module"
import { OrganizationsModule } from "./organizations/organizations.module"
import { UsersModule } from "./users/users.module"
import { RolesModule } from "./roles/roles.module"
import { PermissionsModule } from "./permissions/permissions.module"
import { ClientsModule } from "./clients/clients.module"
import { KycModule } from "./kyc/kyc.module"
import { DocumentsModule } from "./documents/documents.module"
import { InvestmentAccountsModule } from "./investment-accounts/investment-accounts.module"
import { PortfoliosModule } from "./portfolios/portfolios.module"
import { MandatesModule } from "./mandates/mandates.module"
import { SecuritiesModule } from "./securities/securities.module"
import { PricingModule } from "./pricing/pricing.module"
import { FundsModule } from "./funds/funds.module"
import { OrdersModule } from "./orders/orders.module"
import { TradesModule } from "./trades/trades.module"
import { SettlementsModule } from "./settlements/settlements.module"
import { TransactionsModule } from "./transactions/transactions.module"
import { CashModule } from "./cash/cash.module"
import { PositionsModule } from "./positions/positions.module"
import { LedgerModule } from "./ledger/ledger.module"
import { ValuationModule } from "./valuation/valuation.module"
import { PerformanceModule } from "./performance/performance.module"
import { FeesModule } from "./fees/fees.module"
import { ComplianceModule } from "./compliance/compliance.module"
import { ReportingModule } from "./reporting/reporting.module"
import { AuditModule } from "./audit/audit.module"
import { IntegrationsModule } from "./integrations/integrations.module"
import { NotificationsModule } from "./notifications/notifications.module"

@Module({
  imports: [
    PrismaModule,
    HealthModule,
    AuthModule,
    OrganizationsModule,
    UsersModule,
    RolesModule,
    PermissionsModule,
    ClientsModule,
    KycModule,
    DocumentsModule,
    InvestmentAccountsModule,
    PortfoliosModule,
    MandatesModule,
    SecuritiesModule,
    PricingModule,
    FundsModule,
    OrdersModule,
    TradesModule,
    SettlementsModule,
    TransactionsModule,
    CashModule,
    PositionsModule,
    LedgerModule,
    ValuationModule,
    PerformanceModule,
    FeesModule,
    ComplianceModule,
    ReportingModule,
    AuditModule,
    IntegrationsModule,
    NotificationsModule,
  ],
})
export class AppModule {}
