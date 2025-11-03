#!/bin/bash
echo "Starting Laravel server on 0.0.0.0:8000"
echo "Your iPhone can access it at: http://192.168.1.12:8000"
echo ""
cd /home/rahul/public_html/QMAPS
php artisan serve --host=0.0.0.0 --port=8000
