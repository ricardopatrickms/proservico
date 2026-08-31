<?php

namespace Database\Seeders;

use App\Enums\UserStatus;
use App\Models\User;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        User::create([
            'name' => 'Administrador',
            'email' => 'admin@gmail.com',
            'phone' => '(67) 99999-0000',
            'type' => 'admin',
            'city' => 'Campo Grande/MS',
            'status' => UserStatus::Ativo,
            'password' => '@Admin123',
        ]);
    }
}
