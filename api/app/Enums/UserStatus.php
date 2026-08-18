<?php

namespace App\Enums;

enum UserStatus: string
{
    case Ativo = 'ativo';
    case Inativo = 'inativo';
    case Pendente = 'pendente';
    case Excluido = 'excluido';
    case Rejeitado = 'rejeitado';

    public function isActive(): bool
    {
        return $this === self::Ativo;
    }

    public function isPending(): bool
    {
        return $this === self::Pendente;
    }
}
