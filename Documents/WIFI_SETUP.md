# Publish Backend on Local Wi-Fi --- Setup Guide

This guide explains how to expose the backend over your local Wi-Fi
network so the iOS app can connect from a physical device during demos
or interviews.

------------------------------------------------------------------------

## Prerequisites

-   Node.js (LTS recommended)
-   npm
-   Both devices connected to the same Wi-Fi network
-   Backend server must bind to `0.0.0.0`

------------------------------------------------------------------------

# 1. Start the Backend

From the project root:

    cd APIs
    npm install
    npm run seed    # optional
    npm start

You should see:

    Ride backend listening on 3000

------------------------------------------------------------------------

# 2. Verify Backend Locally

On your Mac:

    curl http://localhost:3000/health

Expected response:

    {"status":"ok","now":...}

------------------------------------------------------------------------

# 3. Find Your Machine's Local IP

On macOS (Wi-Fi):

    ipconfig getifaddr en0

Example result:

    192.168.0.42

Do NOT use `192.168.0.1` (usually the router).

------------------------------------------------------------------------

# 4. Test From Another Device (Same Wi-Fi)

On your iPhone (Safari) or another laptop:

    http://<YOUR_MAC_IP>:3000/health

If you receive JSON, the backend is reachable.

------------------------------------------------------------------------

# 5. Configure the iOS App

In Xcode, set:

``` swift
APIClient.shared.setBaseURL("http://<YOUR_MAC_IP>:3000")
```

-   Simulator → use `http://localhost:3000`
-   Physical device → use `http://<YOUR_MAC_IP>:3000`

------------------------------------------------------------------------

# 6. macOS Firewall (If Connection Fails)

If the device cannot reach the backend:

-   System Settings → Network → Firewall
-   Allow incoming connections for `node`
-   Or temporarily disable firewall for demo purposes

------------------------------------------------------------------------

# 7. Important Notes

-   Both devices must be on the same Wi-Fi network.
-   Some guest Wi-Fi networks block device-to-device traffic.
-   This setup is for local development and demo only.
-   Do not expose HTTP endpoints publicly in production.


