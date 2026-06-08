package com.dsrv.wallet.example.wallet.model

import com.dsrv.wallet.sdk.AuthHandler
import com.dsrv.wallet.sdk.ChallengeRequest
import com.dsrv.wallet.sdk.ChallengeResult
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import org.json.JSONObject
import java.io.IOException
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * AuthHandler implementation that delegates authentication to customer backend.
 */
class MyAuthHandler(
    private val backendUrl: String
) : AuthHandler {

    private val httpClient = OkHttpClient()

    override suspend fun requestChallenge(request: ChallengeRequest): ChallengeResult {
        val jsonBody = JSONObject().apply {
            put("sdkId", request.sdkId)
            put("appId", request.appId)
            put("userCredential", JSONObject().apply {
                put("type", request.userCredential.type.name)
                put("value", request.userCredential.value)
                put("provider", request.userCredential.provider)
            })
            put("signingHash", request.signingHash)
            put("deviceInfo", JSONObject().apply {
                put("platform", request.deviceInfo.platform)
                put("publicKey", request.deviceInfo.publicKey)
                put("model", request.deviceInfo.model)
                put("osVersion", request.deviceInfo.osVersion)
                put("isVirtual", request.deviceInfo.isVirtual)
            })
        }.toString()

        return try {
            val (statusCode, responseBody) = post("$backendUrl/sdk/registration", jsonBody)
            android.util.Log.d("MyAuthHandler", "registration response [$statusCode]: $responseBody")
            val json = JSONObject(responseBody)

            val data = if (statusCode in 200..299) json.optJSONObject("data") else null
            val challenge = data?.optString("challenge")?.takeIf { it.isNotEmpty() }
            if (challenge != null) {
                ChallengeResult.Success(challenge)
            } else {
                ChallengeResult.Failure(json.optString("message", "Challenge request failed"))
            }
        } catch (e: Exception) {
            ChallengeResult.Failure(e.message ?: "Network error")
        }
    }

    private suspend fun post(url: String, jsonBody: String): Pair<Int, String> =
        suspendCancellableCoroutine { continuation ->
            val request = Request.Builder()
                .url(url)
                .post(jsonBody.toRequestBody("application/json".toMediaType()))
                .build()

            val call = httpClient.newCall(request)
            continuation.invokeOnCancellation { call.cancel() }

            call.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    if (continuation.isActive) continuation.resumeWithException(e)
                }

                override fun onResponse(call: Call, response: Response) {
                    if (!continuation.isActive) return
                    response.use { resp ->
                        continuation.resume(resp.code to (resp.body?.string().orEmpty()))
                    }
                }
            })
        }
}
