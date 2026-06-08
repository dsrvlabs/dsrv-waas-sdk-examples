import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthController } from './auth/auth.controller';
import { AuthService } from './auth/auth.service';
import { HealthController } from './health/health.controller';
import { TransactionsModule } from './transactions/transactions.module';
import { TransferModule } from './transfer/transfer.module';
import { WellKnownController } from './well-known/well-known.controller';
import { PaymentModule } from './payment/payment.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TransactionsModule,
    TransferModule,
    PaymentModule,
  ],
  controllers: [AuthController, HealthController, WellKnownController],
  providers: [AuthService],
})
export class AppModule {}
