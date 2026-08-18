<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('service_categories', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->foreignId('parent_id')->nullable()->constrained('service_categories')->cascadeOnDelete();
            $table->boolean('active')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });

        $now = now();

        $domesticos = DB::table('service_categories')->insertGetId([
            'name' => 'Serviços Domésticos',
            'parent_id' => null,
            'active' => true,
            'sort_order' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $reformas = DB::table('service_categories')->insertGetId([
            'name' => 'Reformas e Manutenção',
            'parent_id' => null,
            'active' => true,
            'sort_order' => 2,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $clima = DB::table('service_categories')->insertGetId([
            'name' => 'Climatização',
            'parent_id' => null,
            'active' => true,
            'sort_order' => 3,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $children = [
            [$domesticos, 'Diarista'],
            [$domesticos, 'Faxineira'],
            [$domesticos, 'Passadeira'],
            [$domesticos, 'Lavadeira'],
            [$domesticos, 'Cozinheira'],
            [$domesticos, 'Babá'],
            [$domesticos, 'Cuidador de idosos'],
            [$domesticos, 'Pet sitter'],
            [$domesticos, 'Dog walker'],
            [$domesticos, 'Jardinagem'],
            [$reformas, 'Eletricista'],
            [$reformas, 'Encanador'],
            [$reformas, 'Pintor'],
            [$reformas, 'Pedreiro'],
            [$reformas, 'Montagem de móveis'],
            [$clima, 'Instalação de ar-condicionado'],
            [$clima, 'Manutenção de ar-condicionado'],
        ];

        foreach ($children as $index => [$parentId, $name]) {
            DB::table('service_categories')->insert([
                'name' => $name,
                'parent_id' => $parentId,
                'active' => $name !== 'Jardinagem',
                'sort_order' => $index + 1,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('service_categories');
    }
};
