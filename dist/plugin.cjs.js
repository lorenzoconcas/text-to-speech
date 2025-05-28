'use strict';

var core = require('@capacitor/core');

exports.QueueStrategy = void 0;
(function (QueueStrategy) {
    /**
     * Use `Flush` to stop the current request when a new request is sent.
     */
    QueueStrategy[QueueStrategy["Flush"] = 0] = "Flush";
    /**
     * Use `Add` to buffer the speech request. The request will be executed when all previous requests have been completed.
     */
    QueueStrategy[QueueStrategy["Add"] = 1] = "Add";
})(exports.QueueStrategy || (exports.QueueStrategy = {}));

const TextToSpeech = core.registerPlugin('TextToSpeech', {
    web: () => Promise.resolve().then(function () { return web; }).then((m) => new m.TextToSpeechWeb()),
});

function findWordEnd(text, from) {
    let i = from;
    while (i < text.length && !/\s/.test(text[i]))
        i++;
    return i;
}
class TextToSpeechWeb extends core.WebPlugin {
    constructor() {
        super();
        this.speechSynthesis = null;
        if ('speechSynthesis' in window) {
            this.speechSynthesis = window.speechSynthesis;
            window.addEventListener('beforeunload', () => {
                this.stop();
            });
        }
    }
    async speak(options) {
        if (!this.speechSynthesis)
            this.throwUnsupportedError();
        return new Promise((resolve, reject) => {
            const u = this.createSpeechSynthesisUtterance(options);
            u.onboundary = ev => {
                if (ev.name !== 'word')
                    return;
                const start = ev.charIndex;
                const end = typeof ev.charLength === 'number'
                    ? start + ev.charLength
                    : findWordEnd(options.text, start);
                console.log("webtts  range");
                this.notifyListeners('onRangeStart', {
                    start,
                    end,
                    spokenWord: options.text.slice(start, end),
                });
            };
            u.onend = () => {
                console.log("webtts done");
                this.notifyListeners('onDone', {});
                resolve();
            };
            u.onerror = ev => { var _a; return reject((_a = ev.error) !== null && _a !== undefined ? _a : ev); };
            if (options.queueStrategy === 0)
                this.speechSynthesis.cancel();
            console.log("all things setted");
            this.notifyListeners("started", {});
            this.speechSynthesis.speak(u);
        });
    }
    async stop() {
        if (!this.speechSynthesis) {
            this.throwUnsupportedError();
        }
        this.speechSynthesis.cancel();
    }
    async getSupportedLanguages() {
        const voices = this.getSpeechSynthesisVoices();
        const languages = voices.map((voice) => voice.lang);
        const filteredLanguages = languages.filter((v, i, a) => a.indexOf(v) == i);
        return { languages: filteredLanguages };
    }
    async getSupportedVoices() {
        const voices = this.getSpeechSynthesisVoices();
        return { voices };
    }
    async isLanguageSupported(options) {
        const result = await this.getSupportedLanguages();
        const isLanguageSupported = result.languages.includes(options.lang);
        return { supported: isLanguageSupported };
    }
    async openInstall() {
        this.throwUnimplementedError();
    }
    createSpeechSynthesisUtterance(options) {
        const voices = this.getSpeechSynthesisVoices();
        const utterance = new SpeechSynthesisUtterance();
        const { text, lang, rate, pitch, volume, voice } = options;
        if (voice) {
            utterance.voice = voices[voice];
        }
        if (volume) {
            utterance.volume = volume >= 0 && volume <= 1 ? volume : 1;
        }
        if (rate) {
            utterance.rate = rate >= 0.1 && rate <= 10 ? rate : 1;
        }
        if (pitch) {
            utterance.pitch = pitch >= 0 && pitch <= 2 ? pitch : 2;
        }
        if (lang) {
            utterance.lang = lang;
        }
        utterance.text = text;
        return utterance;
    }
    getSpeechSynthesisVoices() {
        if (!this.speechSynthesis) {
            this.throwUnsupportedError();
        }
        if (!this.supportedVoices || this.supportedVoices.length < 1) {
            this.supportedVoices = this.speechSynthesis.getVoices();
        }
        return this.supportedVoices;
    }
    throwUnsupportedError() {
        throw this.unavailable('SpeechSynthesis API not available in this browser.');
    }
    throwUnimplementedError() {
        throw this.unimplemented('Not implemented on web.');
    }
}

var web = /*#__PURE__*/Object.freeze({
    __proto__: null,
    TextToSpeechWeb: TextToSpeechWeb
});

exports.TextToSpeech = TextToSpeech;
//# sourceMappingURL=plugin.cjs.js.map
