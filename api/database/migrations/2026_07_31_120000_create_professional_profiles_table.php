<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('professional_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('category')->nullable();
            $table->string('profession')->nullable();
            $table->string('experience')->nullable();
            $table->string('region')->nullable();
            $table->string('bank')->nullable();
            $table->string('agency')->nullable();
            $table->string('account')->nullable();
            $table->string('account_type')->nullable();
            $table->string('pix_type')->nullable();
            $table->string('pix_key')->nullable();
            $table->string('id_document')->nullable();
            $table->string('certificate')->nullable();
            $table->string('profile_photo')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('professional_profiles');
    }
};
