# Capturing OrcDial screens

The screen gallery is exported over USB from the real M5Dial framebuffer, using the existing UI renderer. No external mockup renderer is used. `raw/` retains the square framebuffer; the presentation PNGs mask only the corners hidden by the round LCD. The captures show static preview states, not live RF readings or animations.

The optional `doc_capture` build disables ESP-NOW and receiver commands. It is a temporary documentation tool, not a user firmware release. The normal `dial` build excludes the capture commands.

## Capture procedure

1. Save the working application firmware and its SHA-256 before changing the device. Stop any serial monitor using the Dial's port.
2. Build the capture application:

   ```sh
   pio run -e doc_capture
   ```

3. On an already provisioned Dial with the matching partition layout, write only the application at `0x10000` using esptool. Leave the bootloader, partition table, and pairing storage intact. Do not erase the device.
4. Install Python dependencies `Pillow` and `pyserial`, then export the frames:

   ```sh
   python tools/capture_screens.py --port COM14 --output docs/screenshots
   ```

   Replace COM14 with the device's port. The script waits for the boot splash, requests each state, drains RGB rows with acknowledgments, and writes the gallery, contact sheets, and manifest. It exits capture mode and closes the port even if a transfer fails.

5. Restore the saved working application at `0x10000`, including after a failed capture. Verify its serial status and normal connection separately.

## Coverage and limits

The gallery includes all current dashboard and selector entries, Home, boot, connection/search previews, the content views exposed by the renderer, alternate tuning styles, and supported focused-control states. It does not exhaust every combination of frequency, control, theme, or live connection state.

Connected/paired status is not fabricated. Dynamic backgrounds are captured at one instant. DEMO, OFFLINE, and placeholder values are retained; a visible dashboard is not evidence that every receiver action is implemented. Consult the control matrix for supported actions.

The USB payload is RGB byte order: LovyanGFX's `bgr888_t` structure stores its bytes as `r`, `g`, `b`. The manifest records capture commands, firmware/source hashes, and output hashes for provenance.
