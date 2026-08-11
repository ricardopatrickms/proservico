import '../models/service_request.dart';
import '../models/user.dart';

class AdminPerson {
  final String id;
  final String name;
  final String email;
  final String phone;
  final AccountType type;
  bool approved;

  AdminPerson({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.type,
    this.approved = true,
  });
}

/// Estado em memória para o front básico (sem backend).
class MockStore {
  MockStore._();
  static final MockStore instance = MockStore._();

  AppUser? currentUser;

  final List<ServiceRequest> clientRequests = [
    ServiceRequest(
      id: '1',
      title: 'Instalação de ar-condicionado',
      description: 'Instalar split 12.000 BTUs na sala.',
      location: 'Rua das Flores, 120 - Campo Grande/MS',
      scheduledAt: DateTime.now().add(const Duration(days: 2)),
      budget: 350,
      needsMaterials: true,
      urgency: ServiceUrgency.normal,
      preferences: 'Prefere manhã',
      photoLabels: ['Foto da sala', 'Tomada'],
      status: ServiceStatus.pending,
    ),
    ServiceRequest(
      id: '2',
      title: 'Reparo elétrico',
      description: 'Troca de disjuntor e revisão do quadro.',
      location: 'Av. Afonso Pena, 850',
      scheduledAt: DateTime.now().add(const Duration(days: 1)),
      budget: 180,
      urgency: ServiceUrgency.urgent,
      preferences: 'Urgente — sem energia no quarto',
      status: ServiceStatus.inProgress,
      professionalName: 'Carlos Eletricista',
    ),
    ServiceRequest(
      id: '3',
      title: 'Pintura de apartamento',
      description: 'Pintura completa de 2 quartos.',
      location: 'Cond. Parque Verde, Bloco B',
      scheduledAt: DateTime.now().subtract(const Duration(days: 5)),
      budget: 900,
      needsMaterials: false,
      status: ServiceStatus.completed,
      professionalName: 'Ana Pinturas',
    ),
  ];

  final List<ProfessionalService> professionalServices = [
    const ProfessionalService(
      id: 'ps1',
      title: 'Instalação de ar-condicionado',
      category: 'Climatização',
      description: 'Instalação e manutenção de splits.',
      priceFrom: 250,
    ),
    const ProfessionalService(
      id: 'ps2',
      title: 'Serviços elétricos residenciais',
      category: 'Elétrica',
      description: 'Instalações, reparos e revisões.',
      priceFrom: 120,
    ),
  ];

  final List<AdminPerson> adminPeople = [
    AdminPerson(
      id: 'c1',
      name: 'Maria Silva',
      email: 'maria@email.com',
      phone: '(67) 99999-1111',
      type: AccountType.client,
    ),
    AdminPerson(
      id: 'c2',
      name: 'João Pereira',
      email: 'joao@email.com',
      phone: '(67) 97777-3333',
      type: AccountType.client,
    ),
    AdminPerson(
      id: 'p1',
      name: 'Carlos Souza',
      email: 'carlos@email.com',
      phone: '(67) 98888-2222',
      type: AccountType.professional,
      approved: true,
    ),
    AdminPerson(
      id: 'p2',
      name: 'Ana Pinturas',
      email: 'ana@email.com',
      phone: '(67) 96666-4444',
      type: AccountType.professional,
      approved: false,
    ),
  ];

  void loginAs(AccountType type) {
    currentUser = type == AccountType.client
        ? const AppUser(
            id: 'c1',
            name: 'Maria Silva',
            email: 'maria@email.com',
            phone: '(67) 99999-1111',
            type: AccountType.client,
            city: 'Campo Grande/MS',
          )
        : const AppUser(
            id: 'p1',
            name: 'Carlos Souza',
            email: 'carlos@email.com',
            phone: '(67) 98888-2222',
            type: AccountType.professional,
            city: 'Campo Grande/MS',
            bio: 'Eletricista e climatização com 8 anos de experiência.',
            approved: true,
          );
  }

  void register({
    required String name,
    required String email,
    required String phone,
    required AccountType type,
  }) {
    currentUser = AppUser(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      phone: phone,
      type: type,
      city: 'Campo Grande/MS',
      approved: type == AccountType.client,
    );

    adminPeople.add(
      AdminPerson(
        id: currentUser!.id,
        name: name,
        email: email,
        phone: phone,
        type: type,
        approved: type == AccountType.client,
      ),
    );
  }

  void logout() => currentUser = null;

  void addClientRequest(ServiceRequest request) {
    clientRequests.insert(0, request);
  }

  void addProfessionalService(ProfessionalService service) {
    professionalServices.insert(0, service);
  }

  void updateProfessionalService(ProfessionalService service) {
    final index = professionalServices.indexWhere((s) => s.id == service.id);
    if (index >= 0) professionalServices[index] = service;
  }

  void removeProfessionalService(String id) {
    professionalServices.removeWhere((s) => s.id == id);
  }

  void updateCurrentUser(AppUser user) => currentUser = user;

  void setPersonApproval(String id, bool approved) {
    for (final person in adminPeople) {
      if (person.id == id) {
        person.approved = approved;
        break;
      }
    }
  }
}
