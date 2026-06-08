import {
  IsBoolean,
  IsNotEmpty,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class UserCredentialDto {
  @IsString()
  @IsNotEmpty()
  type: string;

  @IsString()
  @IsNotEmpty()
  value: string;

  @IsString()
  @IsOptional()
  provider: string;
}

export class DeviceInfoDto {
  @IsString()
  @IsNotEmpty()
  platform: string;

  @IsString()
  @IsOptional()
  publicKey: string;

  @IsString()
  @IsNotEmpty()
  model: string;

  @IsString()
  @IsNotEmpty()
  osVersion: string;

  @IsBoolean()
  isVirtual: boolean;

  @IsString()
  @IsOptional()
  attestationObject?: string;
}

export class AuthenticateDto {
  @IsString()
  @IsNotEmpty()
  sdkId: string;

  @IsString()
  @IsNotEmpty()
  appId: string;

  @ValidateNested()
  @Type(() => UserCredentialDto)
  userCredential: UserCredentialDto;

  @IsString()
  @IsOptional()
  signingHash?: string;

  @ValidateNested()
  @Type(() => DeviceInfoDto)
  deviceInfo: DeviceInfoDto;
}
