<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_addresses', function (Blueprint $table) {
            if (! Schema::hasColumn('user_addresses', 'address')) {
                $table->string('address')->nullable()->after('label');
            }
            if (! Schema::hasColumn('user_addresses', 'city')) {
                $table->string('city')->nullable()->after('address');
            }
            if (! Schema::hasColumn('user_addresses', 'state')) {
                $table->string('state', 2)->nullable()->after('city');
            }
            if (! Schema::hasColumn('user_addresses', 'cep')) {
                $table->string('cep', 12)->nullable()->after('state');
            }
            if (! Schema::hasColumn('user_addresses', 'reference_point')) {
                $table->string('reference_point')->nullable()->after('cep');
            }
            if (! Schema::hasColumn('user_addresses', 'latitude')) {
                $table->decimal('latitude', 10, 7)->nullable()->after('reference_point');
            }
            if (! Schema::hasColumn('user_addresses', 'longitude')) {
                $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            }
        });
    }

    public function down(): void
    {
        Schema::table('user_addresses', function (Blueprint $table) {
            foreach (['longitude', 'latitude', 'reference_point', 'cep', 'state', 'city', 'address'] as $column) {
                if (Schema::hasColumn('user_addresses', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
