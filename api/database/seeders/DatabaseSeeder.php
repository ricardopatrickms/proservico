<?php

namespace Database\Seeders;

use App\Models\ProfessionalProfile;
use App\Models\ProfessionalService;
use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::create([
            'name' => 'Administrador',
            'email' => 'admin@proservico.com',
            'phone' => '(67) 99999-0000',
            'type' => 'admin',
            'city' => 'Campo Grande/MS',
            'approved' => true,
            'password' => 'password',
        ]);

        $client = User::create([
            'name' => 'Maria Silva',
            'email' => 'maria@email.com',
            'phone' => '(67) 99999-1111',
            'type' => 'client',
            'city' => 'Campo Grande/MS',
            'approved' => true,
            'password' => 'password',
        ]);

        $professional = User::create([
            'name' => 'Carlos Souza',
            'email' => 'carlos@email.com',
            'phone' => '(67) 98888-2222',
            'type' => 'professional',
            'city' => 'Campo Grande/MS',
            'bio' => 'Eletricista e climatização com 8 anos de experiência.',
            'cpf' => '123.456.789-00',
            'approved' => true,
            'password' => 'password',
        ]);

        ProfessionalProfile::create([
            'user_id' => $professional->id,
            'category' => 'Elétrica',
            'profession' => 'Eletricista',
            'experience' => '5 a 10 anos',
            'region' => 'Campo Grande/MS',
            'bank' => 'Banco do Brasil',
            'agency' => '1234',
            'account' => '56789-0',
            'account_type' => 'Corrente',
            'pix_type' => 'CPF',
            'pix_key' => '123.456.789-00',
        ]);

        User::create([
            'name' => 'Ana Pinturas',
            'email' => 'ana@email.com',
            'phone' => '(67) 96666-4444',
            'type' => 'professional',
            'city' => 'Campo Grande/MS',
            'approved' => false,
            'password' => 'password',
        ]);

        ProfessionalService::create([
            'user_id' => $professional->id,
            'title' => 'Instalação de ar-condicionado',
            'category' => 'Climatização',
            'description' => 'Instalação e manutenção de splits.',
            'price_from' => 250,
        ]);

        ProfessionalService::create([
            'user_id' => $professional->id,
            'title' => 'Serviços elétricos residenciais',
            'category' => 'Elétrica',
            'description' => 'Instalações, reparos e revisões.',
            'price_from' => 120,
        ]);

        ServiceRequest::create([
            'client_id' => $client->id,
            'title' => 'Instalação de ar-condicionado',
            'description' => 'Instalar split 12.000 BTUs na sala.',
            'location' => 'Rua das Flores, 120 - Campo Grande/MS',
            'scheduled_at' => now()->addDays(2),
            'budget' => 350,
            'needs_materials' => true,
            'urgency' => 'normal',
            'preferences' => 'Prefere manhã',
            'photo_labels' => ['Foto da sala', 'Tomada'],
            'status' => 'pending',
        ]);

        ServiceRequest::create([
            'client_id' => $client->id,
            'professional_id' => $professional->id,
            'title' => 'Reparo elétrico',
            'description' => 'Troca de disjuntor e revisão do quadro.',
            'location' => 'Av. Afonso Pena, 850',
            'scheduled_at' => now()->addDay(),
            'budget' => 180,
            'urgency' => 'urgent',
            'preferences' => 'Urgente — sem energia no quarto',
            'status' => 'in_progress',
        ]);

        unset($admin);
    }
}
