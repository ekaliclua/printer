EKALI = EKALI or {}
EKALI.Printer = EKALI.Printer or {}

EKALI.Printer.InsertDatabase = true -- Insert the printer items into the database if they don't exist.

EKALI.Printer.Items = {
    ["basic_printer"] = {
        label = "Printer à faible capacité", -- Nom du printer.
        capacity = 500000, -- Capacité du printer en argent.
        printedAmount = 10000, -- Montant d'argent imprimé à chaque intervalle.
        interval = 0.5, -- Intervalle de temps entre chaque impression en seconde.
        model = "prop_printer_01", -- Model du printer.
        batteryRemove = 0.1, -- Montant de batterie retiré à chaque impression.
        paperRemove = 1, -- Montant de papier retiré à chaque impression.
        inkRemove = 2, -- Montant d'encre retiré à chaque impression.
    }
}