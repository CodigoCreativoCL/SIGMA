(function (c, l, a, r, i, t, y) {
    c[a] = c[a] || function () {
        (c[a].q = c[a].q || []).push(arguments);
    };

    t = l.createElement(r);
    t.async = 1;
    t.src = "https://www.clarity.ms/tag/" + i;

    y = l.getElementsByTagName(r)[0];
    y.parentNode.insertBefore(t, y);

})(window, document, "clarity", "script", "y08fq0a0kq");


window.addEventListener("load", function () {

    var data = window.ClarityData || {};

    if (typeof clarity === "function") {

        clarity("identify",
            data.idUsuario || "",
            null,
            null,
            data.nombreUsuario || ""
        );

        clarity("set", "id_usuario", String(data.idUsuario || ""));
        clarity("set", "nombre_usuario", String(data.nombreUsuario || ""));
        clarity("set", "ip_usuario", String(data.ipUsuario || ""));
    }

});