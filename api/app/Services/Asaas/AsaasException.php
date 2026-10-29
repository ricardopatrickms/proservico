<?php

namespace App\Services\Asaas;

use Exception;
use Throwable;

class AsaasException extends Exception
{
    /**
     * @param  array<string, mixed>|null  $response
     */
    public function __construct(
        string $message,
        public readonly ?int $status = null,
        public readonly ?array $response = null,
        ?Throwable $previous = null,
    ) {
        parent::__construct($message, 0, $previous);
    }
}
