const { createApp, ref } = Vue

createApp({
    setup() {
        const show = ref(false)
        const printerId = ref(0)
        const money = ref(0)
        const battery = ref(0)
        const paper = ref(0)
        const ink = ref(0)

        const formatMoney = () => {
            return new Intl.NumberFormat('en-US', {
                style: 'currency',
                currency: 'USD',
                minimumFractionDigits: 0
            }).format(money.value)
        }

        const lerpColor = (color1, color2, t) => {
            const c1 = color1.match(/\w\w/g).map((c) => parseInt(c, 16));
            const c2 = color2.match(/\w\w/g).map((c) => parseInt(c, 16));
            const interpolated = c1.map((start, i) => Math.round(start + (c2[i] - start) * t));
            return `#${interpolated.map((c) => c.toString(16).padStart(2, '0')).join('')}`;
        };

        const batteryFillColor = () => {
            const value = battery.value;

            // Définitions des seuils et des couleurs associées
            const colorStops = [
                { threshold: 5, color: '#ff4b1f' },    // Rouge intense
                { threshold: 30, color: '#ff6a00' },  // Rouge/orange
                { threshold: 50, color: '#f6d365' },  // Jaune
                { threshold: 75, color: '#96c93d' },  // Vert/jaune
                { threshold: 95, color: '#00c851' },  // Vert vif
                { threshold: 100, color: '#007e33' }  // Vert foncé
            ];

            // Trouver les deux couleurs entre lesquelles interpoler
            for (let i = 1; i < colorStops.length; i++) {
                if (value <= colorStops[i].threshold) {
                    const lower = colorStops[i - 1];
                    const upper = colorStops[i];
                    const t = (value - lower.threshold) / (upper.threshold - lower.threshold);
                    return lerpColor(lower.color, upper.color, t);
                }
            }

            // Si aucune correspondance (valeur hors des seuils), retour par défaut
            return '#007e33'; // Vert vif pour 100%
        };



        window.addEventListener('message', (event) => {
            const { type, data } = event.data
            if (type === 'UPDATE_PRINTER_DATA') {
                printerId.value = data.printerId
                money.value = data.money
                battery.value = data.battery
                paper.value = data.paper
                ink.value = data.ink
                show.value = true;
            }
        })

        return {
            show,
            printerId,
            money,
            battery,
            formatMoney,
            batteryFillColor,
            paper,
            ink
        }
    }
}).mount('#app')