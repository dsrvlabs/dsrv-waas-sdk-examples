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

  // Stable per-device id (survives reinstall) used by the backend to dedup reinstalls.
  // Required to be present, but may be an empty string: the SDK intentionally sends "" as a
  // fail-safe (unreliable SSAID / Keychain write failure) to tell the backend to skip dedup.
  @IsString()
  deviceId: string;
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
