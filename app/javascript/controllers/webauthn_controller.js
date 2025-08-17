import { Controller } from "@hotwired/stimulus"

// Helper: base64url encode/decode ArrayBuffers
function bufferToBase64url(buffer) {
  const bytes = new Uint8Array(buffer)
  let binary = ""
  for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i])
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "")
}

function base64urlToBuffer(base64url) {
  // pad back
  let base64 = base64url.replace(/-/g, "+").replace(/_/g, "/")
  while (base64.length % 4) base64 += "="
  const str = atob(base64)
  const bytes = new Uint8Array(str.length)
  for (let i = 0; i < str.length; i++) bytes[i] = str.charCodeAt(i)
  return bytes.buffer
}

export default class extends Controller {
  static targets = ["status"]

  connect() {}

  async register(event) {
    event.preventDefault()
    this._setStatus("")
    try {
      const creationOptionsRes = await fetch("/webauthn/options/creation", { method: "POST", headers: { "Accept": "application/json", "X-CSRF-Token": this._csrfToken() } })
      const options = await creationOptionsRes.json()

      // Convert challenge and user.id to ArrayBuffers
      options.publicKey.challenge = base64urlToBuffer(options.publicKey.challenge)
      if (options.publicKey.user && options.publicKey.user.id) {
        options.publicKey.user.id = new TextEncoder().encode(options.publicKey.user.id)
      }
      if (options.publicKey.excludeCredentials) {
        options.publicKey.excludeCredentials = options.publicKey.excludeCredentials.map((cred) => ({ ...cred, id: base64urlToBuffer(cred.id) }))
      }

      const credential = await navigator.credentials.create(options)
      const credentialJSON = this._credentialToJSON(credential)

      const verifyRes = await fetch("/webauthn/create", {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": this._csrfToken() },
        body: JSON.stringify({ credential: credentialJSON })
      })
      const result = await verifyRes.json()
      if (result.ok) {
        this._setStatus("Security key registered.")
      } else {
        throw new Error(result.error || "Registration failed")
      }
    } catch (e) {
      this._setStatus(`Error: ${e.message}`)
    }
  }

  async authenticate(event) {
    event.preventDefault()
    this._setStatus("")
    try {
      const requestOptionsRes = await fetch("/webauthn/options/request", { method: "POST", headers: { "Accept": "application/json", "X-CSRF-Token": this._csrfToken() } })
      if (!requestOptionsRes.ok) {
        const e = await requestOptionsRes.json().catch(() => ({}))
        throw new Error(e.error || `Failed to get options (${requestOptionsRes.status})`)
      }
      const options = await requestOptionsRes.json()

      options.publicKey.challenge = base64urlToBuffer(options.publicKey.challenge)
      if (options.publicKey.allowCredentials) {
        options.publicKey.allowCredentials = options.publicKey.allowCredentials.map((cred) => ({ ...cred, id: base64urlToBuffer(cred.id) }))
      }

      const assertion = await navigator.credentials.get(options)
      const assertionJSON = this._credentialToJSON(assertion)

      const verifyRes = await fetch("/webauthn/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json" },
        body: JSON.stringify({ credential: assertionJSON })
      })
      const result = await verifyRes.json()
      if (result.ok) {
        // Complete 2FA: navigate to root
        window.location.href = "/"
      } else {
        throw new Error(result.error || "Authentication failed")
      }
    } catch (e) {
      this._setStatus(`Error: ${e.message}`)
    }
  }

  _credentialToJSON(cred) {
    if (!cred) return null
    const clientDataJSON = bufferToBase64url(cred.response.clientDataJSON)

    if (cred.type === "public-key" && cred.response.attestationObject) {
      return {
        id: cred.rawId ? bufferToBase64url(cred.rawId) : cred.id,
        type: cred.type,
        response: {
          attestationObject: bufferToBase64url(cred.response.attestationObject),
          clientDataJSON
        }
      }
    } else {
      return {
        id: cred.rawId ? bufferToBase64url(cred.rawId) : cred.id,
        type: cred.type,
        response: {
          authenticatorData: bufferToBase64url(cred.response.authenticatorData),
          clientDataJSON,
          signature: bufferToBase64url(cred.response.signature),
          userHandle: cred.response.userHandle ? bufferToBase64url(cred.response.userHandle) : null
        }
      }
    }
  }

  _setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
