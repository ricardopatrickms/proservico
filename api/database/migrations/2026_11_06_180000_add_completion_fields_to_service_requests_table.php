<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('service_requests', function (Blueprint $table) {
            if (! Schema::hasColumn('service_requests', 'started_at')) {
                $table->timestamp('started_at')->nullable()->after('status');
            }
            if (! Schema::hasColumn('service_requests', 'completed_at')) {
                $table->timestamp('completed_at')->nullable()->after('started_at');
            }
            if (! Schema::hasColumn('service_requests', 'completion_checklist')) {
                $table->json('completion_checklist')->nullable()->after('completed_at');
            }
            if (! Schema::hasColumn('service_requests', 'completion_notes')) {
                $table->text('completion_notes')->nullable()->after('completion_checklist');
            }
            if (! Schema::hasColumn('service_requests', 'completion_photos')) {
                $table->json('completion_photos')->nullable()->after('completion_notes');
            }
        });
    }

    public function down(): void
    {
        Schema::table('service_requests', function (Blueprint $table) {
            $columns = [
                'started_at',
                'completed_at',
                'completion_checklist',
                'completion_notes',
                'completion_photos',
            ];

            $existing = array_values(array_filter(
                $columns,
                fn (string $column) => Schema::hasColumn('service_requests', $column),
            ));

            if ($existing !== []) {
                $table->dropColumn($existing);
            }
        });
    }
};
