<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('service_requests', function (Blueprint $table) {
            if (! Schema::hasColumn('service_requests', 'latitude')) {
                $table->decimal('latitude', 10, 7)->nullable()->after('cep');
            }
            if (! Schema::hasColumn('service_requests', 'longitude')) {
                $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            }
        });
    }

    public function down(): void
    {
        Schema::table('service_requests', function (Blueprint $table) {
            if (Schema::hasColumn('service_requests', 'longitude')) {
                $table->dropColumn('longitude');
            }
            if (Schema::hasColumn('service_requests', 'latitude')) {
                $table->dropColumn('latitude');
            }
        });
    }
};
