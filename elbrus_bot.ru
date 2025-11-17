import sqlite3
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ApplicationBuilder, CommandHandler, CallbackQueryHandler, ContextTypes
from apscheduler.schedulers.asyncio import AsyncIOScheduler

BOT_TOKEN = "8545939138:AAGMlkFhroyFFhz_LItAhK-iqAfWp-qgBf4"

# --- База данных ---
conn = sqlite3.connect("database.db", check_same_thread=False)
cursor = conn.cursor()
cursor.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, referrer INTEGER, joined TIMESTAMP DEFAULT CURRENT_TIMESTAMP)")
conn.commit()

# --- Главное меню ---
def get_main_menu():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("💬 Войти в платный чат", callback_data="chat")],
        [InlineKeyboardButton("📞 Консультация", callback_data="consult")],
        [InlineKeyboardButton("🤝 Моя реферальная ссылка", callback_data="ref")],
        [InlineKeyboardButton("📊 Моя статистика", callback_data="stats")]
    ])

# --- Команда /start ---
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    args = context.args

    # Проверка реферала
    referrer = None
    if args and args[0].isdigit():
        referrer = int(args[0])
        cursor.execute("INSERT INTO users (id, referrer) VALUES (?, ?)", (user_id, referrer))
    else:
        cursor.execute("INSERT OR IGNORE INTO users (id) VALUES (?)", (user_id,))
    conn.commit()

    await update.message.reply_text(
        "👋 Привет! Добро пожаловать в Elbrus Bot.\nВыбери действие:",
        reply_markup=get_main_menu()
    )

# --- Обработка кнопок ---
async def handle_buttons(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user_id = query.from_user.id

    if query.data == "chat":
        await query.edit_message_text("💬 Закрытый чат: доступ после оплаты USDT TRC-20 → TQWaLHTjundsvsoRJjtFsPysUqJaiqeU1H")
    elif query.data == "consult":
        await query.edit_message_text("📞 Консультация: пиши @elbrustyle")
    elif query.data == "ref":
        ref_link = f"https://t.me/{context.bot.username}?start={user_id}"
        await query.edit_message_text(f"🤝 Твоя реферальная ссылка:\n{ref_link}")
    elif query.data == "stats":
        cursor.execute("SELECT COUNT(*) FROM users WHERE referrer=?", (user_id,))
        referrals = cursor.fetchone()[0]
        await query.edit_message_text(f"📊 Статистика:\nТы пригласил {referrals} человек.")

# --- Автопрогрев ---
async def auto_message(context: ContextTypes.DEFAULT_TYPE):
    for user in cursor.execute("SELECT id FROM users").fetchall():
        try:
            await context.bot.send_message(user[0], "🔥 Новые связки и кейсы уже доступны! Загляни в чат.")
        except:
            pass

# --- Запуск ---
app = ApplicationBuilder().token(BOT_TOKEN).build()
app.add_handler(CommandHandler("start", start))
app.add_handler(CallbackQueryHandler(handle_buttons))

# Планировщик автопрогрева
scheduler = AsyncIOScheduler()
scheduler.add_job(auto_message, "interval", hours=24, args=[app.bot])
scheduler.start()

print("✅ Бот запущен")
app.run_polling()
