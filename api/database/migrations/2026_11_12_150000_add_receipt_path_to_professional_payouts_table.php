<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('professional_payouts')) {
            return;
        }

        Schema::table('professional_payouts', function (Blueprint $table) {
            if (! Schema::hasColumn('professional_payouts', 'receipt_path')) {
                $table->string('receipt_path')->nullable()->after('admin_notes');
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('professional_payouts')) {
            return;
        }

        Schema::table('professional_payouts', function (Blueprint $table) {
            if (Schema::hasColumn('professional_payouts', 'receipt_path')) {
                $table->dropColumn('receipt_path');
            }
        });
    }
};
