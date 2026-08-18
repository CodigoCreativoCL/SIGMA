const BASE_URL = window.location.origin + window.location.pathname.substring(0, window.location.pathname.toLowerCase().indexOf("/intranet/") + 10);
const URL_ESTADO_MATERIAL = `${BASE_URL}/WebService/WsMenuMaterialApoyos.asmx/EstadoMaterial`;

//  Manejo principal de estado 
function EstadoMaterial(idEncoded, idMeGusta, idNoMeGusta, idVisto, tipo) {
    var meGusta = $("#" + idMeGusta);
    var noMeGusta = $("#" + idNoMeGusta);
    var visto = $("#" + idVisto);

    var badgeLike = meGusta.closest(".icon-badge.like");
    var badgeDislike = noMeGusta.closest(".icon-badge.dislike");
    var badgeView = visto.closest(".icon-badge.view");

    var liked = badgeLike.attr("data-active") === "true";
    var disliked = badgeDislike.attr("data-active") === "true";
    var viewed = badgeView.attr("data-active") === "true";

    if (tipo === 1) { // Me gusta
        var nLike = parseInt(meGusta.text().replace(/\./g, "")) || 0;
        var nDislike = parseInt(noMeGusta.text().replace(/\./g, "")) || 0;

        if (!liked) {
            meGusta.text((nLike + 1).toLocaleString());
            badgeLike.attr("data-active", "true");
            showTooltipOnce(badgeLike.closest(".stat-item"), "¡Me gusta!", "rojo");

            if (disliked && nDislike > 0) {
                noMeGusta.text((nDislike - 1).toLocaleString());
                badgeDislike.attr("data-active", "false");
            }
        } else {
            meGusta.text(Math.max(nLike - 1, 0).toLocaleString());
            badgeLike.attr("data-active", "false");
        }
    }
    else if (tipo === 2) { //  No me gusta
        var nDislike = parseInt(noMeGusta.text().replace(/\./g, "")) || 0;
        var nLike = parseInt(meGusta.text().replace(/\./g, "")) || 0;

        if (!disliked) {
            noMeGusta.text((nDislike + 1).toLocaleString());
            badgeDislike.attr("data-active", "true");
            showTooltipOnce(badgeDislike.closest(".stat-item"), "¡No me gusta!", "gris");

            if (liked && nLike > 0) {
                meGusta.text((nLike - 1).toLocaleString());
                badgeLike.attr("data-active", "false");
            }
        } else {
            noMeGusta.text(Math.max(nDislike - 1, 0).toLocaleString());
            badgeDislike.attr("data-active", "false");
        }
    }
    else if (tipo === 3) { // Visto
        var nVisto = parseInt(visto.text().replace(/\./g, "")) || 0;

        //  Sumar siempre, incluso si ya fue visto antes
        visto.text((nVisto + 1).toLocaleString());
        badgeView.attr("data-active", "true");

        // Tooltip cada vez que se ve
        showTooltipOnce(badgeView.closest(".stat-item"), "¡Visto!", "azul");
    }

    // === AJAX ===
    $.ajax({
        type: "POST",
        url: URL_ESTADO_MATERIAL,
        data: JSON.stringify({ id: idEncoded, tipo: tipo }),
        contentType: "application/json; charset=utf-8",
        dataType: "json",
        timeout: 2500
    });
}


// === Tooltip animado al hacer clic ===
function showTooltipOnce(target, text, color) {
    if (target.find(".custom-tooltip").length > 0) return;

    const tip = $("<div class='custom-tooltip " + color + "'>" + text + "</div>");
    target.append(tip);

    tip.css({
        opacity: 0,
        transform: "translate(-50%, 8px)"
    });

    tip.animate(
        { opacity: 1, bottom: "124%" },
        250,
        "swing",
        function () {
            setTimeout(function () {
                tip.animate(
                    { opacity: 0, bottom: "134%" },
                    450,
                    "swing",
                    function () {
                        tip.remove();
                    }
                );
            }, 500);
        }
    );
}


// === Tooltip permanente al pasar el mouse si está activo ===
$(document).on("mouseenter", ".icon-badge", function () {
    const badge = $(this);
    const isActive = badge.attr("data-active") === "true";
    if (!isActive) return;

    let text = "";
    let color = "";

    if (badge.hasClass("like")) {
        text = "Te gusta este contenido";
        color = "rojo";
    } else if (badge.hasClass("dislike")) {
        text = "No te gusta este contenido";
        color = "gris";
    } else if (badge.hasClass("view")) {
        text = "Visto";
        color = "azul";
    }

    if (!text) return;

    // Crear tooltip flotante mientras esté el cursor encima
    const tip = $("<div class='custom-tooltip " + color + "'>" + text + "</div>");
    badge.append(tip);

    tip.css({
        opacity: 0,
        bottom: "125%",
        transform: "translate(-50%, 4px)"
    }).animate({ opacity: 1, bottom: "132%" }, 250, "swing");
});

$(document).on("mouseleave", ".icon-badge", function () {
    $(this).find(".custom-tooltip").stop(true).fadeOut(200, function () {
        $(this).remove();
    });
});


document.addEventListener("DOMContentLoaded", function () {

    const btnCapsulas = document.getElementById("btnCapsulas");
    const menuCapsulas = document.getElementById("menuCapsulas");

    // ====== Toggle cápsulas ======
    if (btnCapsulas && menuCapsulas) {
        btnCapsulas.addEventListener("click", function (e) {
            e.preventDefault();
            e.stopPropagation();
            const estabaAbierto = menuCapsulas.style.display === "block";
            cerrarTodos();
            if (!estabaAbierto) menuCapsulas.style.display = "block";
        });
    }

    // ====== Cierre global (click fuera) ======
    document.addEventListener("click", function (e) {
        const clickedInside =
            (btnCapsulas && (btnCapsulas.contains(e.target) || menuCapsulas.contains(e.target)))

        if (!clickedInside) cerrarTodos();
    });

    // ====== Función de cierre general ======
    function cerrarTodos() {
        if (menuCapsulas) menuCapsulas.style.display = "none";
    }
});


