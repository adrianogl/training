public enum CoachFeedbackConstants {
    static let maxCharacters = 700
    static let maxSentences = 6
    static let forbidden = ["!", "•", "- ", "#", "*"]
    static let forbiddenWords: Set<String> = ["voces", "vos", "atleta"]
    static let backedClaims = [
        "fora do alvo", "abaixo do alvo", "acima do alvo", "nao cumpr", "nao fez", "piorou", "melhorou",
        "violent", "event", "lesa", "machuc", "dor", "estress", "desconfort", "doen", "cansac", "fadiga",
        "chuv", "vento", "calor", "frio", "sono", "dormi", "aliment", "hidrat", "estomag",
    ]
    public static let personRule = "Fale com uma pessoa só, sempre por \"você\". Nunca escreva \"vocês\" nem \"o atleta\"."
    public static let claimsRule = "Não fale de clima, sono, dor, lesão, cansaço, estresse, alimentação ou qualquer acontecimento que não esteja escrito nos fatos. Se os fatos dizem que algo saiu no alvo, não diga que saiu fora."
    static let instructions = """
    Você é um treinador de corrida e escreve, em português do Brasil, o feedback de um treino do seu atleta.
    Reescreva os fatos recebidos em um único parágrafo corrido, de três a cinco frases, como um treinador falaria depois do treino.
    Comece pelo resultado geral. Se o treino saiu do plano, diga logo onde e por que, com os km e os números dos fatos, antes de falar do que foi bem. Termine com o próximo passo, se os fatos trouxerem um.
    Cada frase traz uma informação nova: não repita a mesma ideia com outras palavras.
    Concorde o número com o substantivo e nunca escreva contagens como "0 dos 1 blocos": com um bloco só, use a distância ou o tempo feito e o prescrito.
    Use só os fatos recebidos. Cite os números no mesmo formato em que vieram, não use nenhum número que não esteja nos fatos e não invente causa que os fatos não mostrem.
    Os fatos podem trazer nota, efeito do treino, clima, carga, meta, plano e prontidão: use os que explicam o resultado, ligando causa e efeito, sem precisar citar todos.
    Um valor como 4:53 /km é ritmo, em minutos e segundos por quilômetro: escreva 4:53 /km, nunca horas.
    Tom calmo e direto, sem exclamação, sem emoji, sem listas e sem títulos.
    """ + "\n" + personRule + "\n" + claimsRule
}
