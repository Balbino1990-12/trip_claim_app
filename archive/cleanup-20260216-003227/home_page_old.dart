import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../trip_claim/trip_claim_page.dart';
import '../new_connection/new_connection_page.dart';
import '../history/trip_claim_history_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    _HomeContent(),
    const Center(child: Text('Services - Coming Soon')),
    TripClaimHistoryPage(),
    const Center(child: Text('Account - Coming Soon')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF0070BA),
        title: Row(
          children: [
            Image.asset('web/icons/logo_edtl.png', width: 36, height: 36),
            const SizedBox(width: 12),
            const Text(
              'EDTL, E.P',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
            PopupMenuButton<String>(
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              color: Colors.white,
              elevation: 12,
              icon: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0070BA), Color(0xFF00C6FB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.transparent,
                  child: Icon(Icons.person, color: Colors.white, size: 28),
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0070BA), Color(0xFF00C6FB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Profile',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.settings,
                          color: Color(0xFF0070BA),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.shade100,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.logout,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Logout',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'profile') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile selected')),
                  );
                } else if (value == 'settings') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings selected')),
                  );
                } else if (value == 'logout') {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ],
        ),
        elevation: 0,
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF0070BA),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Services',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: _pages[_selectedIndex],
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
          // Banner/Carousel
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF0070BA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.flash_on, color: Colors.yellow, size: 48),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Welcome to EDTL, E.P Mobile App! You can Claim your trip and new Connection here.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Quick Actions Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavCard(
                icon: Icons.bolt,
                label: 'Trip Claim',
                color: Colors.orange.shade100,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TripClaimPage()),
                  );
                },
              ),
              _NavCard(
                icon: Icons.add_link,
                label: 'New Connection',
                color: Colors.blue.shade100,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewConnectionPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Status Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 24),
          // Recent Transactions
          const Text(
            'Latest News',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const ListTile(
              leading: Icon(Icons.bolt, color: Colors.amber),
              title: Text(
                'Workshop Estratéjiku kona-ba Estabelesementu Klaridade Papel no Responsabilidade, Identifikasaun Inefisiénsia, Desafiu no Solusaun ba Dezenvolvimentu',
              ),
              subtitle: Text(
                'Díli, 21 Janeiru 2026 – Eletricidade de Timor-Leste, Empresa Pública (EDTL, E.P), iha loron kuarta-feira ne’e hala’o workshop estratéjiku kona-ba estabelece klaridade papel no responsabilidade, identifika inefisiénsia, desafiu no solusaun ba dezenvolvimentu, ne’ebé realiza iha Maubara Room, Timor Plaza.',
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const ListTile(
              leading: Icon(Icons.receipt, color: Colors.blue),
              title: Text(
                'Construção Novo Edifíçio EDTL, E.P Iha Muniçipio Lautem, Hahú Ona Lançamento Primeira Pedra',
              ),
              subtitle: Text(
                'Díli, 15 Janeiro 2026| Eletricidade de Timor-Leste, Empresa Pública, (EDTL, E.P) liu-hosi companha manan-nain KRD ENTERPRISE PTE, LTD',
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ),
          const SizedBox(height: 24),
          // News/Promo
          const Text(
            'Info & Promo', // You may want to change this to 'Info & Promo' or 'News & Promo'
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Card(
            color: Colors.yellow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const ListTile(
              leading: Icon(Icons.campaign, color: Colors.orange),
              title: Text('Discount Promo for Power Upgrade!'),
              subtitle: Text(
                'Get a discount for upgrading your home electricity capacity.',
              ),
            ),
          ),
          const SizedBox(height: 24),
          // PLN Menu Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _PlnMenuButton(icon: Icons.payment, label: 'Bills'),
              _PlnMenuButton(icon: Icons.history, label: 'History'),
              _PlnMenuButton(icon: Icons.settings, label: 'Settings'),
            ],
          ),
          const SizedBox(height: 24),
          // Latest News Card with Read More
          Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(Icons.article, color: Colors.blue.shade700),
              title: Text(
                'The President of the Executive Commission of EDTL, E.P. participated in the 15th Meeting of the Expert Working Group on Energy Connectivity (EWG-EC) in Bangkok-Thailand',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('12/Mar/2025'),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      launchUrl(
                        Uri.parse(
                          'https://edtl-ep.tl/news-detail/en/2025/03/2979994931093398342981/the-president-of-the-executive-commission-of-edtl-e-p-participated-in-the-15th-meeting-of-the-expert-working-group-on-energy-connectivity-ewg-ec-in-bangkok-thailand/',
                        ),
                      );
                    },
                    child: Text(
                      'Read more...',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.blue.shade700,
              ),
              onTap: () {
                launchUrl(
                  Uri.parse(
                    'https://edtl-ep.tl/news-detail/en/2025/03/2979994931093398342981/the-president-of-the-executive-commission-of-edtl-e-p-participated-in-the-15th-meeting-of-the-expert-working-group-on-energy-connectivity-ewg-ec-in-bangkok-thailand/',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    )
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NavCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 120,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.deepOrange),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlnMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlnMenuButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Icon(icon, color: Color(0xFF0070BA), size: 32),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
