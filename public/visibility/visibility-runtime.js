/**
 * KRIM OS — Visibility Suite Runtime Engine
 * Version: 2.6.0-OCT
 * Description: Core telemetry polling, WebSocket connection manager, and real-time map data binder.
 */

(function () {
    'use strict';

    class KrimVisibilityRuntime {
        constructor(config = {}) {
            this.endpoint = config.endpoint || 'wss://telemetry.krim.os/v1/stream';
            this.reconnectInterval = config.reconnectInterval || 5000;
            this.activeShipmentId = config.shipmentId || 'QTE-2026-OCT-0101';
            this.socket = null;
            this.isInitialized = false;
        }

        init() {
            console.info(`[KRIM OS Runtime] Initializing Visibility Suite Engine for shipment: ${this.activeShipmentId}`);
            this.connectWebSocket();
            this.bindUIEventListeners();
            this.isInitialized = true;
        }

        connectWebSocket() {
            try {
                // Simulated WebSocket connection for real-time AIS / IoT telemetry streams
                console.log(`[KRIM OS Runtime] Connecting to telemetry stream at ${this.endpoint}...`);
                
                // Mock connection success event handler
                setTimeout(() => {
                    console.info('[KRIM OS Runtime] WebSocket telemetry stream established successfully.');
                    this.dispatchTelemetryEvent({ type: 'STATUS', message: 'Connected to AIS & IoT Feed' });
                }, 1000);

            } catch (error) {
                console.error('[KRIM OS Runtime] Failed to establish telemetry socket connection:', error);
                setTimeout(() => this.connectWebSocket(), this.reconnectInterval);
            }
        }

        dispatchTelemetryEvent(payload) {
            const event = new CustomEvent('krim:telemetry', { detail: payload });
            window.dispatchEvent(event);
        }

        bindUIEventListeners() {
            document.addEventListener('DOMContentLoaded', () => {
                const copyButtons = document.querySelectorAll('button');
                copyButtons.forEach(btn => {
                    if (btn.textContent.includes('Copy')) {
                        btn.addEventListener('click', () => {
                            const input = btn.previousElementSibling;
                            if (input && input.tagName === 'INPUT') {
                                input.select();
                                navigator.clipboard.writeText(input.value);
                                const originalText = btn.textContent;
                                btn.textContent = 'Copied! ✓';
                                setTimeout(() => btn.textContent = originalText, 2000);
                            }
                        });
                    }
                });
            });
        }
    }

    // Auto-instantiate runtime engine globally
    window.KrimVisibility = new KrimVisibilityRuntime();
    window.KrimVisibility.init();

})();
