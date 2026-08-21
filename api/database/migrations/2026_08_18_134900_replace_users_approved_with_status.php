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
                $table->enum('status', ['ATIVO', 'INATIVO', 'PENDENTE', 'EXCLUIDO', 'REJEITADO'])
                    ->default('ATIVO')
                    ->after('cpf');
            });
        }

        if (Schema::hasColumn('users', 'approved')) {
            DB::table('users')->where('approved', true)->update(['status' => 'ATIVO']);
            DB::table('users')
                ->where('approved', false)
                ->where('type', 'professional')
                ->update(['status' => 'PENDENTE']);
            DB::table('users')
                ->where('approved', false)
                ->where('type', '!=', 'professional')
                ->update(['status' => 'INATIVO']);

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
            DB::table('users')->where('status', 'ATIVO')->update(['approved' => true]);
            DB::table('users')->where('status', '!=', 'ATIVO')->update(['approved' => false]);

            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('status');
            });
        }
    }
};
