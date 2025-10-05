// After successful payment, show this:
class VoucherScreen extends StatelessWidget {
  final String voucherCode;
  
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Your Voucher')),
      body: Center(
        child: Column(
          children: [
            Text('Show this to merchant:'),
            Text(voucherCode, style: TextStyle(fontSize: 48)),
            QrImageView(data: voucherCode, size: 200),
          ],
        ),
      ),
    );
  }
}