<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $column = DB::selectOne(
            "SELECT COLUMN_TYPE FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE()
               AND TABLE_NAME = 'service_requests'
               AND COLUMN_NAME = 'status'"
        );

        if ($column && str_contains((string) $column->COLUMN_TYPE, 'awaiting_payment')) {
            return;
        }

        DB::statement("ALTER TABLE service_requests MODIFY COLUMN status ENUM('pending', 'awaiting_payment', 'in_progress', 'completed', 'cancelled') NOT NULL DEFAULT 'pending'");
    }

    public function down(): void
    {
        DB::statement("UPDATE service_requests SET status = 'pending' WHERE status = 'awaiting_payment'");
        DB::statement("ALTER TABLE service_requests MODIFY COLUMN status ENUM('pending', 'in_progress', 'completed', 'cancelled') NOT NULL DEFAULT 'pending'");
    }
};
