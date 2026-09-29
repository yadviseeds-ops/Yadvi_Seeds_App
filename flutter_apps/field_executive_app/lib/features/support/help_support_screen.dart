import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D4A32),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0D4A32), Color(0xFF1A7A55)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.support_agent, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text('Need Help?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                  SizedBox(height: 4),
                  Text('Contact your Admin or Supervisor for assistance.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Contact Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D4A32))),
            const SizedBox(height: 12),
            _buildContactCard(
              icon: Icons.phone,
              title: 'Call Admin',
              subtitle: 'Call your supervisor for urgent issues.',
              color: Colors.green,
              onTap: () {},
            ),
            _buildContactCard(
              icon: Icons.chat,
              title: 'WhatsApp Admin',
              subtitle: 'Send a WhatsApp message to your admin.',
              color: Colors.teal,
              onTap: () {},
            ),
            const SizedBox(height: 24),

            const Text('Quick Help', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D4A32))),
            const SizedBox(height: 12),
            _buildFaqItem('How do I check in at a shop?', 'Go to Visits → tap Check In on a Pending visit.'),
            _buildFaqItem('Why can I not see my assigned orders?', 'Orders are visible only after Admin assigns them to you.'),
            _buildFaqItem('My location is not updating?', 'Go to My Location → tap Update My Location → allow GPS permission.'),
            _buildFaqItem('How do I submit EOD?', 'Go to EOD Report → add notes → tap Submit EOD Report.'),
            _buildFaqItem('How do I logout?', 'Go to Profile → tap Logout.'),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('App Info', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D4A32))),
                  SizedBox(height: 8),
                  Text('YADVI Hybrid Seeds', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Field Executive App v1.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('Phase 14 Build', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))]),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, size: 16, color: Color(0xFF0D4A32)),
              const SizedBox(width: 6),
              Expanded(child: Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ],
          ),
          const SizedBox(height: 6),
          Text(answer, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
