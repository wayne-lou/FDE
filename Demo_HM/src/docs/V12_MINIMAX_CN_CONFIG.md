# V12 - MiniMax China / International Voice Provider Config

This version updates the Python 3.13 voice bridge to support both MiniMax China mainland and international API hosts.

## Recommended for China Mainland

Use the mainland MiniMax Open Platform key and host:

```bat
cd C:\inetpub\demos\demo_hm\voice_clone_service
set HM_VOICE_PROVIDER=minimax
set MINIMAX_REGION=cn
set MINIMAX_API_HOST=https://api.minimax.chat
set MINIMAX_API_KEY=YOUR_NEW_MINIMAX_KEY
set HM_PUBLIC_BASE_URL=http://demos.e-xanke.com/demo_hm
python server.py --project-root C:\inetpub\demos\demo_hm
```

Do not paste the API key into source code, GitHub, screenshots, or chat logs.

## Optional GroupId

Some older MiniMax accounts / examples require `GroupId` as query string. Newer accounts may not need it.

If your console shows GroupId and the API returns authorization/account errors, add:

```bat
set MINIMAX_GROUP_ID=YOUR_GROUP_ID
```

The bridge will then call URLs like:

```text
https://api.minimax.chat/v1/t2a_v2?GroupId=YOUR_GROUP_ID
```

## International fallback

If using the international platform, set:

```bat
set MINIMAX_REGION=international
set MINIMAX_API_HOST=https://api.minimax.io
```

If your specific account says `https://api.minimaxi.chat`, use that exact host:

```bat
set MINIMAX_API_HOST=https://api.minimaxi.chat
```

## Check service health

Open:

```text
http://127.0.0.1:7866/health
```

It should return JSON containing:

```json
{
  "success": true,
  "minimax_configured": true,
  "minimax_api_host": "https://api.minimax.chat"
}
```

## D-ID / Talking Head

D-ID is an international provider. For China mainland network/payment convenience, you can keep D-ID disabled first. The HoloMemory page will still show local photo/avatar animation and cloned voice playback.

To enable D-ID later:

```bat
set D_ID_API_KEY=YOUR_DID_BASIC_KEY
```

D-ID requires public image/audio URLs, so `HM_PUBLIC_BASE_URL` must be reachable from the public Internet.
