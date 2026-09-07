#!/bin/bash
# Pornire Roulette Lab pe macOS / Linux. Dublu-click pe acest fisier.
cd "$(dirname "$0")" || exit 1

PYTHON=""
for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
        PYTHON="$candidate"
        break
    fi
done

if [ -z "$PYTHON" ]; then
    echo
    echo "  Nu am gasit Python pe acest calculator."
    echo "  Instaleaza-l de aici: https://www.python.org/downloads/"
    echo
    read -r -p "  Apasa Enter ca sa inchizi." _
    exit 1
fi

echo
echo "  Pornesc Roulette Lab..."
echo "  Se deschide singur in browser. Lasa aceasta fereastra deschisa."
echo "  Ca sa opresti: apasa Ctrl+C."
echo
"$PYTHON" -m roulette_lab serve || {
    echo
    echo "  Ceva n-a mers. Mesajul de eroare este mai sus."
    read -r -p "  Apasa Enter ca sa inchizi." _
}
