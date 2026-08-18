<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('users', 'status')) {
            Schema::table('users', function (Blueprint $table) {
                $table->enum('status', ['ativo', 'inativo', 'pendente', 'excluido', 'rejeitado'])
                    ->default('ativo')
                    ->after('cpf');
            });
        }

        if (Schema::hasColumn('users', 'approved')) {
            DB::table('users')->where('approved', true)->update(['status' => 'ativo']);
            DB::table('users')
                ->where('approved', false)
                ->where('type', 'professional')
                ->update(['status' => 'pendente']);
            DB::table('users')
                ->where('approved', false)
                ->where('type', '!=', 'professional')
                ->update(['status' => 'inativo']);

            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('approved');
            });
        }
    }

    public function down(): void
    {
        if (! Schema::hasColumn('users', 'approved')) {
            Schema::table('users', function (Blueprint $table) {
                $table->boolean('approved')->default(true)->after('cpf');
            });
        }

        if (Schema::hasColumn('users', 'status')) {
            DB::table('users')->where('status', 'ativo')->update(['approved' => true]);
            DB::table('users')->where('status', '!=', 'ativo')->update(['approved' => false]);

            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('status');
            });
        }
    }
};
