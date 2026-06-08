import { Controller, Get, Header } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';

const ASSET_DIR = __dirname;

@Controller('.well-known')
export class WellKnownController {
  private readonly appleAppSiteAssociation = JSON.parse(
    fs.readFileSync(path.join(ASSET_DIR, 'apple-app-site-association'), 'utf8'),
  );

  private readonly assetLinks = JSON.parse(
    fs.readFileSync(path.join(ASSET_DIR, 'assetlinks.json'), 'utf8'),
  );

  @Get('apple-app-site-association')
  @Header('Content-Type', 'application/json')
  getAppleAppSiteAssociation() {
    return this.appleAppSiteAssociation;
  }

  @Get('assetlinks.json')
  @Header('Content-Type', 'application/json')
  getAssetLinks() {
    return this.assetLinks;
  }
}
