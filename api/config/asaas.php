<?php

return [
    'api_key' => env('ASAAS_API_KEY'),

    'base_url' => env('ASAAS_BASE_URL', 'https://sandbox.asaas.com/api/v3'),

    /**
     * Token compartilhado para validar webhooks (query ?token= ou header X-Asaas-Webhook-Token).
     */
    'webhook_token' => env('ASAAS_WEBHOOK_TOKEN'),

    /**
     * Percentual da plataforma sobre o valor do profissional.
     * Ex.: profissional R$100 → cliente paga R$115.
     */
    'platform_fee_percent' => (float) env('ASAAS_PLATFORM_FEE_PERCENT', 15),
];
