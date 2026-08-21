<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('users', 'status')) {
            return;
        }

        $driver = Schema::getConnection()->getDriverName();

        if ($driver === 'mysql') {
            // MySQL trata ENUM case-insensitive: não dá para ter 'ativo' e 'ATIVO' juntos.
            DB::statement("ALTER TABLE users MODIFY COLUMN status VARCHAR(20) NOT NULL DEFAULT 'ativo'");

            DB::table('users')->whereRaw('LOWER(status) = ?', ['ativo'])->update(['status' => 'ATIVO']);
            DB::table('users')->whereRaw('LOWER(status) = ?', ['inativo'])->update(['status' => 'INATIVO']);
            DB::table('users')->whereRaw('LOWER(status) = ?', ['pendente'])->update(['status' => 'PENDENTE']);
            DB::table('users')->whereRaw('LOWER(status) = ?', ['excluido'])->update(['status' => 'EXCLUIDO']);
            DB::table('users')->whereRaw('LOWER(status) = ?', ['rejeitado'])->update(['status' => 'REJEITADO']);

            DB::statement("ALTER TABLE users MODIFY COLUMN status ENUM(
                'ATIVO', 'INATIVO', 'PENDENTE', 'EXCLUIDO', 'REJEITADO'
            ) NOT NULL DEFAULT 'ATIVO'");

            return;
        }

        DB::table('users')->whereRaw('LOWER(status) = ?', ['ativo'])->update(['status' => 'ATIVO']);
        DB::table('users')->whereRaw('LOWER(status) = ?', ['inativo'])->update(['status' => 'INATIVO']);
        DB::table('users')->whereRaw('LOWER(status) = ?', ['pendente'])->update(['status' => 'PENDENTE']);
        DB::table('users')->whereRaw('LOWER(status) = ?', ['excluido'])->update(['status' => 'EXCLUIDO']);
        DB::table('users')->whereRaw('LOWER(status) = ?', ['rejeitado'])->update(['status' => 'REJEITADO']);
    }

    public function down(): void
    {
        if (! Schema::hasColumn('users', 'status')) {
            return;
        }

        $driver = Schema::getConnection()->getDriverName();

        if ($driver === 'mysql') {
            DB::statement("ALTER TABLE users MODIFY COLUMN status VARCHAR(20) NOT NULL DEFAULT 'ATIVO'");

            DB::table('users')->whereRaw('UPPER(status) = ?', ['ATIVO'])->update(['status' => 'ativo']);
            DB::table('users')->whereRaw('UPPER(status) = ?', ['INATIVO'])->update(['status' => 'inativo']);
            DB::table('users')->whereRaw('UPPER(status) = ?', ['PENDENTE'])->update(['status' => 'pendente']);
            DB::table('users')->whereRaw('UPPER(status) = ?', ['EXCLUIDO'])->update(['status' => 'excluido']);
            DB::table('users')->whereRaw('UPPER(status) = ?', ['REJEITADO'])->update(['status' => 'rejeitado']);

            DB::statement("ALTER TABLE users MODIFY COLUMN status ENUM(
                'ativo', 'inativo', 'pendente', 'excluido', 'rejeitado'
            ) NOT NULL DEFAULT 'ativo'");

            return;
        }

        DB::table('users')->whereRaw('UPPER(status) = ?', ['ATIVO'])->update(['status' => 'ativo']);
        DB::table('users')->whereRaw('UPPER(status) = ?', ['INATIVO'])->update(['status' => 'inativo']);
        DB::table('users')->whereRaw('UPPER(status) = ?', ['PENDENTE'])->update(['status' => 'pendente']);
        DB::table('users')->whereRaw('UPPER(status) = ?', ['EXCLUIDO'])->update(['status' => 'excluido']);
        DB::table('users')->whereRaw('UPPER(status) = ?', ['REJEITADO'])->update(['status' => 'rejeitado']);
    }
};
