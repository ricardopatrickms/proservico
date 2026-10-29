<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('asaas_webhook_events')) {
            return;
        }

        Schema::create('asaas_webhook_events', function (Blueprint $table) {
            $table->id();
            $table->string('event')->nullable()->index();
            $table->string('asaas_payment_id')->nullable()->index();
            $table->json('payload');
            $table->timestamp('processed_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('asaas_webhook_events');
    }
};
