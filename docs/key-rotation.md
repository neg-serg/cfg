# API Key Rotation

Leaked keys (cleaned from logs, need revocation and replacement).

## Leaked keys

| Provider   | Gopass path     | Leaked key pattern         | Status |
|------------|-----------------|---------------------------|--------|
| Cerebras   | `api/cerebras`  | `csk-62w5cypk4vc...`      | Needs rotation |
| DeepSeek   | `api/deepseek`  | `sk-3fffa79edcca...`      | Needs rotation |

## Steps

1. **DeepSeek** — https://platform.deepseek.com/api_keys
   - Log in, delete old key, create new key
   - `gopass insert api/deepseek` ← paste new key

2. **Cerebras** — https://cloud.cerebras.ai (open in your browser, Cloudflare blocks headless)
   - Settings → API Keys, delete old key, create new key
   - `gopass insert api/cerebras` ← paste new key

3. **Apply** — `just force` to regenerate proxypilot config with new keys
