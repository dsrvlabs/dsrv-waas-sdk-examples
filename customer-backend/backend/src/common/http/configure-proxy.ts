import axios from 'axios';
import { HttpsProxyAgent } from 'https-proxy-agent';

/**
 * 프록시 URL 의 자격증명({@code user:pass@}) 을 마스킹한다.
 * 운영 로그 수집/공유 시 자격증명이 평문 노출되지 않도록 host:port 만 남긴다.
 */
function maskProxyCredentials(rawUrl: string): string {
  try {
    const url = new URL(rawUrl);
    if (url.username || url.password) {
      url.username = '***';
      url.password = '';
    }
    return url.toString();
  } catch {
    // URL 파싱 실패 시 자격증명 추정 구간(`//...@`)만 안전하게 제거
    return rawUrl.replace(/\/\/[^@/]+@/, '//***@');
  }
}

/**
 * 폐쇄망 등 프록시 경유 환경 지원.
 *
 * <p>{@code HTTPS_PROXY}(또는 {@code https_proxy}) 가 설정돼 있으면 axios 전역
 * 기본값에 CONNECT 터널 에이전트를 붙인다. axios 내장 proxy 처리는 HTTPS 대상에
 * 대해 CONNECT 터널링이 온전치 않아(squid 에서 TLS 조기 종료) {@code proxy:false}
 * 로 끄고 {@code httpsAgent} 로 위임한다 — curl 의 프록시 동작과 동일.
 *
 * <p>환경변수가 없으면 아무 것도 바꾸지 않으므로 직접 통신(DMZ/로컬) 환경과도
 * 그대로 호환된다. 프록시 변수는 쿠버네티스 컨테이너 등 인프라가 OS 환경변수로
 * 주입하는 값이라 {@code .env} 에 별도 설정할 필요가 없다.
 */
export function configureProxyFromEnv(): void {
  const proxyUrl = process.env.HTTPS_PROXY ?? process.env.https_proxy;
  if (!proxyUrl) return;

  axios.defaults.httpsAgent = new HttpsProxyAgent(proxyUrl);
  axios.defaults.proxy = false;

  console.log(`HTTPS proxy enabled via ${maskProxyCredentials(proxyUrl)}`);
}
