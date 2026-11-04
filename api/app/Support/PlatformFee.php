<?php

namespace App\Support;

final class PlatformFee
{
    /**
     * @return array{professional_amount: float, platform_fee: float, total_amount: float, percent: float}
     */
    public static function fromProfessionalAmount(float|string $professionalAmount): array
    {
        $percent = (float) config('asaas.platform_fee_percent', 15);
        $professional = round((float) $professionalAmount, 2);
        $fee = round($professional * ($percent / 100), 2);
        $total = round($professional + $fee, 2);

        return [
            'professional_amount' => $professional,
            'platform_fee' => $fee,
            'total_amount' => $total,
            'percent' => $percent,
        ];
    }
}
