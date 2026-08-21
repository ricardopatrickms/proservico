<?php

namespace App\Enums;

enum UserStatus: string
{
    case Ativo = 'ATIVO';
    case Inativo = 'INATIVO';
    case Pendente = 'PENDENTE';
    case Excluido = 'EXCLUIDO';
    case Rejeitado = 'REJEITADO';

    public function isActive(): bool
    {
        return $this === self::Ativo;
    }

    public function isPending(): bool
    {
        return $this === self::Pendente;
    }
}
