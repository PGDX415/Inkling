import Foundation

/// Provides a daily rotating quote / writing prompt
struct DailyQuote {
    /// Get today's quote, deterministically based on the day of year
    static func today() -> String {
        let all = quotes
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (dayOfYear - 1) % all.count
        return all[index]
    }

    /// Curated writing prompts and literary quotes
    private static let quotes: [String] = [
        "今天，写下你最感激的一件事。 Today, write about one thing you're grateful for.",
        "如果今天是一本书的最后一页，你想写什么？ If today were the last page of a book, what would you write?",
        "最近一次让你心跳加速的瞬间是什么？ What's the last moment that made your heart race?",
        "写给十年后的自己。 Write a letter to yourself ten years from now.",
        "今天你笑了吗？为什么？ Did you smile today? Why?",
        "描述今天遇见的一个陌生人。 Describe a stranger you encountered today.",
        "如果今天重来一次，你会改变什么？ If you could relive today, what would you change?",
        "你最近在逃避什么？ What have you been avoiding lately?",
        "今天学到的最重要的东西是什么？ What's the most important thing you learned today?",
        "写下此刻窗外看到的事物。 Write down what you see outside your window right now.",
        "最近让你感动的一句话。 A sentence that moved you recently.",
        "你害怕什么？ What are you afraid of?",
        "今天哪一刻让你觉得活着真好？ What moment today made you feel truly alive?",
        "写给一个人，但你不会真的发出去。 Write to someone — but you'll never send it.",
        "如果只能用三个词总结今天，是什么？ Summarize today in three words.",
        "你最近在想念谁？ Who have you been missing lately?",
        "今天有哪个小细节让你觉得美好？ What small detail made today beautiful?",
        "你觉得自己十年后会在做什么？ What do you think you'll be doing in ten years?",
        "记录今天听到的一句有趣的话。 Record something interesting you heard today.",
        "你最近做过的最勇敢的事。 The bravest thing you've done recently.",
        "如果今天能回到过去某一天，你选择哪一天？ If you could go back to any day in the past, which one?",
        "你今天吃的什么？味道如何？ What did you eat today? How did it taste?",
        "最近一次想哭但忍住了。The last time you wanted to cry but held back.",
        "你觉得自己最珍贵的东西是什么？ What do you treasure most?",
        "今天有没有人说了一句让你心里一暖的话？ Did someone say something today that warmed your heart?",
        "你最近做过什么梦？ What did you dream about recently?",
        "写下今天身体的感觉——疲惫、轻盈、酸痛、舒畅？ Write down how your body feels today.",
        "如果有一天你完全自由了，你第一件事去做什么？ If you were completely free, what's the first thing you'd do?",
        "最近让你失眠的事。 What's been keeping you up at night?",
        "今天，你和谁在一起？感觉如何？ Who did you spend today with? How did it feel?",
    ]
}
