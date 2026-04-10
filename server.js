const escpos = require('escpos');
escpos.USB = require('escpos-usb');

const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'ibul-print' });
});

app.get('/printers', (req, res) => {
  try {
    const devices = escpos.USB.findPrinter();
    res.json({
      ok: true,
      devices: devices.map((d, i) => ({
        index: i,
        vendorId: d.deviceDescriptor?.idVendor,
        productId: d.deviceDescriptor?.idProduct,
      })),
    });
  } catch (err) {
    console.error('PRINTER_LIST_ERROR:', err);
    res.status(500).json({ ok: false, error: String(err) });
  }
});

app.post('/print', (req, res) => {
  try {
    const { items = [], total = 0, title = 'IBUL RESTAURANT' } = req.body || {};

    const device = new escpos.USB(0x0416, 0x5011);
    const printer = new escpos.Printer(device, { encoding: 'CP857' });

    device.open((error) => {
      if (error) {
        console.error('USB_OPEN_ERROR:', error);
        return res.status(500).json({ ok: false, error: String(error) });
      }

      try {
        printer
          .encode('CP857')
          .align('CT')
          .style('B')
          .size(1, 1)
          .text(title)
          .text('-----------------------------')
          .align('LT')
          .style('NORMAL');

        if (!items.length) {
          printer.text('URUN YOK');
        } else {
          items.forEach((item) => {
            const name = item.name || 'Urun';
            const qty = item.qty || 1;
            printer.text(`${name} x${qty}`);
          });
        }

        printer
          .text('-----------------------------')
          .align('RT')
          .style('B')
          .text(`TOPLAM: ${total} TL`)
          .feed(2)
          .cut()
          .close(() => res.json({ ok: true }));
      } catch (printErr) {
        console.error('PRINT_PIPELINE_ERROR:', printErr);
        return res.status(500).json({ ok: false, error: String(printErr) });
      }
    });
  } catch (err) {
    console.error('PRINT_ERROR:', err);
    res.status(500).json({ ok: false, error: String(err) });
  }
});

app.listen(3001, () => {
  console.log('PRINT SERVER READY -> http://localhost:3001');
});
