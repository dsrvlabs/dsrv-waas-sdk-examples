#pragma once
#include <stdint.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * encrypt key를 등록합니다. 앱 시작 시 한번만 호출.
 *
 * encrypt_key_ptr: AES-256 encrypt key (32바이트)
 * encrypt_key_len: 반드시 32
 *
 * 반환값:
 *  0: 성공
 * -1: 이미 등록됨
 * -2: 잘못된 키 (null 또는 길이 != 32)
 * -3: panic 발생
 */
int32_t mpc_init(const uint8_t *encrypt_key_ptr, uint32_t encrypt_key_len);

/**
 * MPC Keygen을 실행합니다.
 *
 * uuid: 세션 UUID (C 문자열)
 * parties: 참여자 수 (1~10)
 * threshold: 최소 서명 인원 (1~parties)
 * callback: 라운드 통신 콜백
 *
 * 반환: MpcResponse JSON (C 문자열). 호출자가 mpc_free_string으로 해제해야 합니다.
 */
const char *mpc_keygen(const char *uuid,
                       uint16_t parties,
                       uint16_t threshold,
                       const char *(*callback)(const char *));

/**
 * MPC Sign을 실행합니다.
 *
 * key_data: 암호화된 key_data (C 문자열, AEAD JSON)
 * message: 서명할 메시지 (hex, C 문자열)
 * uuid: 세션 UUID (C 문자열)
 * threshold: 최소 서명 인원 (1~10)
 * callback: 라운드 통신 콜백
 *
 * 반환: MpcResponse JSON.
 */
const char *mpc_sign(const char *key_data,
                     const char *message,
                     const char *uuid,
                     uint16_t threshold,
                     const char *(*callback)(const char *));

/**
 * MPC KeyRefresh를 실행합니다.
 *
 * uuid: 세션 UUID (C 문자열)
 * key_data: 암호화된 key_data (C 문자열, AEAD JSON)
 * share: 키 조각 (C 문자열)
 * signatories: 참여자 수 (1~10)
 * threshold: 최소 서명 인원 (1~signatories)
 * callback: 라운드 통신 콜백
 *
 * 반환: MpcResponse JSON.
 */
const char *mpc_key_refresh(const char *uuid,
                            const char *key_data,
                            const char *share,
                            uint16_t signatories,
                            uint16_t threshold,
                            const char *(*callback)(const char *));

/**
 * KeyRefresh용 키 조각을 생성합니다.
 *
 * party_size: 참여자 수 (1~10)
 * 반환: MpcResponse JSON. encrypt key, callback 불필요 (순수 연산).
 */
const char *mpc_make_shares(uint16_t party_size);

/**
 * 암호화된 key_data에서 공개키를 추출합니다.
 *
 * key_data: 암호화된 key_data (C 문자열, AEAD JSON)
 * 반환: MpcResponse JSON.
 */
const char *mpc_extract_pub_key(const char *key_data);

/**
 * Rust가 반환한 C 문자열을 해제합니다.
 *
 * mpc_keygen, mpc_sign 등이 반환한 문자열은 반드시 이 함수로 해제해야 합니다.
 */
void mpc_free_string(char *ptr);

#ifdef __cplusplus
} // extern "C"
#endif
