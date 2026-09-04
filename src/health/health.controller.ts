import { Controller, Get, HttpCode } from "@nestjs/common"

import { PrismaService } from "../prisma/prisma.service"

@Controller()
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  index() {
    return {
      service: "oriva-asset",
      endpoints: ["GET /health"],
    }
  }

  // Touches Postgres so a deploy that cannot reach the database reports
  // unhealthy rather than looking fine and failing on the first request.
  @Get("health")
  @HttpCode(200)
  async health() {
    try {
      await this.prisma.$queryRaw`SELECT 1`
      return { status: "ok", database: "ok" }
    } catch {
      return { status: "degraded", database: "unreachable" }
    }
  }
}
