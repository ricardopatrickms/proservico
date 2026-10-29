<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('professional_profile_service_category', function (Blueprint $table) {
            $table->id();
            $table->foreignId('professional_profile_id')
                ->constrained(indexName: 'ppsc_profile_fk')
                ->cascadeOnDelete();
            $table->foreignId('service_category_id')
                ->constrained(indexName: 'ppsc_category_fk')
                ->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['professional_profile_id', 'service_category_id'], 'profile_category_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('professional_profile_service_category');
    }
};
