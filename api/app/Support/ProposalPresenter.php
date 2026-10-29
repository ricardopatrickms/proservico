<?php

namespace App\Support;

use App\Models\ServiceProposal;
use App\Models\User;
use Illuminate\Support\Collection;

final class ProposalPresenter
{
    public static function apply(ServiceProposal $proposal, ?User $viewer = null): ServiceProposal
    {
        $fee = PlatformFee::fromProfessionalAmount($proposal->getRawOriginal('amount') ?? $proposal->amount);

        $proposal->setAttribute('professional_amount', $fee['professional_amount']);
        $proposal->setAttribute('platform_fee', $fee['platform_fee']);
        $proposal->setAttribute('client_amount', $fee['total_amount']);
        $proposal->setAttribute('platform_fee_percent', $fee['percent']);

        // Cliente/admin veem o valor com taxa; profissional vê o valor que propôs.
        if ($viewer === null || $viewer->isClient() || $viewer->isAdmin()) {
            $proposal->setAttribute('amount', $fee['total_amount']);
        } else {
            $proposal->setAttribute('amount', $fee['professional_amount']);
        }

        return $proposal;
    }

    /**
     * @param  Collection<int, ServiceProposal>|iterable<ServiceProposal>  $proposals
     * @return Collection<int, ServiceProposal>
     */
    public static function collection(iterable $proposals, ?User $viewer = null): Collection
    {
        return collect($proposals)
            ->map(fn (ServiceProposal $proposal) => self::apply($proposal, $viewer))
            ->values();
    }
}
