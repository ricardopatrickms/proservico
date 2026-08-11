<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('service_requests', function (Blueprint $table) {
            $table->string('category')->nullable()->after('title');
            $table->string('address')->nullable()->after('location');
            $table->string('city')->nullable()->after('address');
            $table->string('state', 2)->nullable()->after('city');
            $table->string('cep', 12)->nullable()->after('state');
            $table->string('reference_point')->nullable()->after('cep');
            $table->string('preferred_period')->nullable()->after('scheduled_at');
            $table->decimal('budget_min', 10, 2)->nullable()->after('budget');
            $table->decimal('budget_max', 10, 2)->nullable()->after('budget_min');
            $table->boolean('accepts_negotiation')->default(true)->after('budget_max');
            $table->string('materials_responsible')->nullable()->after('needs_materials');
            $table->text('materials_details')->nullable()->after('materials_responsible');
            $table->boolean('prefers_good_ratings')->nullable()->after('preferences');
            $table->string('gender_preference')->nullable()->after('prefers_good_ratings');
        });

        // Amplia urgência para incluir emergência (MySQL enum).
        DB::statement("ALTER TABLE service_requests MODIFY urgency ENUM('normal', 'urgent', 'emergency') NOT NULL DEFAULT 'normal'");
    }

    public function down(): void
    {
        DB::statement("ALTER TABLE service_requests MODIFY urgency ENUM('normal', 'urgent') NOT NULL DEFAULT 'normal'");

        Schema::table('service_requests', function (Blueprint $table) {
            $table->dropColumn([
                'category',
                'address',
                'city',
                'state',
                'cep',
                'reference_point',
                'preferred_period',
                'budget_min',
                'budget_max',
                'accepts_negotiation',
                'materials_responsible',
                'materials_details',
                'prefers_good_ratings',
                'gender_preference',
            ]);
        });
    }
};
