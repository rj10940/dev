#!/bin/bash
# Check CPU usage and kill high CPU processes

echo "🔍 Checking CPU usage..."
echo ""

echo "=== Top 10 CPU consuming processes ==="
ps aux --sort=-%cpu | head -11

echo ""
echo "=== All npm processes ==="
ps aux | grep npm | grep -v grep

echo ""
echo "=== All node processes ==="
ps aux | grep node | grep -v grep

echo ""
echo "=== All webpack processes ==="
ps aux | grep webpack | grep -v grep

echo ""
read -p "❓ Do you want to kill all npm/node processes? (y/N): " confirm

if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    echo ""
    echo "🔪 Killing all npm processes..."
    pkill -9 -f "npm run" || echo "No npm run processes found"
    
    echo "🔪 Killing all node processes..."
    pkill -9 -f "node.*webpack" || echo "No webpack processes found"
    
    echo "🔪 Killing all node processes (general)..."
    pkill -9 node || echo "No node processes found"
    
    echo ""
    echo "✅ Processes killed!"
    
    echo ""
    echo "📊 Current CPU usage:"
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print "CPU Usage: " 100 - $1"%"}'
    
    echo ""
    echo "📊 Remaining processes:"
    ps aux --sort=-%cpu | head -11
else
    echo "❌ No processes killed"
fi

