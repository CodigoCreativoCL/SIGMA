<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="_Default" %>


<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="Server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    Inicio
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="Server">

    <div class="dashboard">

        <!-- Header de bienvenida -->
        <div class="dashboard-hero">
            <div class="dashboard-hero-info">
                <h1 class="dashboard-hero-title">
                    <asp:Literal ID="litSaludo" runat="server" />,
                   
                    <asp:Literal ID="litNombreUsuario" runat="server" />
                    <span class="dashboard-hero-emoji">👋</span>
                </h1>
                <div class="dashboard-hero-meta">
                    <span class="dashboard-chip">
                        <i class="mdi mdi-shield-account-outline"></i>
                        <asp:Literal ID="litPerfilActual" runat="server" />
                    </span>
                    <span class="dashboard-chip dashboard-chip-outline">
                        <i class="mdi mdi-calendar-month-outline"></i>
                        <asp:Literal ID="litFechaActual" runat="server" />
                    </span>
                </div>
            </div>
            <div class="dashboard-hero-svg" aria-hidden="true">
                <svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg">
                    <defs>
                        <filter id="heroGlow">
                            <feGaussianBlur result="blur" stdDeviation="4" />
                            <feComposite in="SourceGraphic" in2="blur" operator="over" />
                        </filter>
                    </defs>
                    <g transform="translate(200, 200)">
                        <circle cx="0" cy="0" fill="#ffffff" r="14">
                            <animate attributeName="r" dur="3s" repeatCount="indefinite" values="14;18;14" />
                        </circle>
                        <g opacity="0.72" stroke="rgba(0,212,255,0.48)" stroke-width="1.5">
                            <line x1="0" y1="0" x2="60" y2="-40">
                                <animateTransform attributeName="transform" type="rotate" from="0" to="360" dur="20s" repeatCount="indefinite" />
                            </line>
                            <line x1="0" y1="0" x2="-50" y2="-70">
                                <animateTransform attributeName="transform" type="rotate" from="0" to="-360" dur="25s" repeatCount="indefinite" />
                            </line>
                            <line x1="0" y1="0" x2="40" y2="80">
                                <animateTransform attributeName="transform" type="rotate" from="0" to="360" dur="30s" repeatCount="indefinite" />
                            </line>
                            <line x1="0" y1="0" x2="-80" y2="30">
                                <animateTransform attributeName="transform" type="rotate" from="0" to="-360" dur="22s" repeatCount="indefinite" />
                            </line>
                        </g>
                        <g>
                            <circle fill="#00D4FF" filter="url(#heroGlow)" r="12">
                                <animateMotion dur="8s" path="M -100,0 A 100,100 0 1 1 100,0 A 100,100 0 1 1 -100,0" repeatCount="indefinite" />
                            </circle>
                            <circle fill="#7EFFFF" r="9">
                                <animateMotion dur="12s" path="M 0,-130 A 130,130 0 1 0 0,130 A 130,130 0 1 0 0,-130" repeatCount="indefinite" />
                            </circle>
                            <circle fill="#00B8E0" r="13">
                                <animateMotion dur="15s" path="M 150,0 A 150,150 0 1 1 -150,0 A 150,150 0 1 1 150,0" repeatCount="indefinite" />
                            </circle>
                        </g>
                        <path d="M -100,0 L 0,-130 L 150,0 L 0,130 L -100,0 Z" fill="none" opacity="0.22" stroke="#00D4FF" stroke-width="1" />
                        <circle cx="0" cy="0" fill="none" r="0" stroke="rgba(0,212,255,0.52)" stroke-width="2">
                            <animate attributeName="r" dur="4s" from="0" to="190" repeatCount="indefinite" />
                            <animate attributeName="opacity" dur="4s" from="0.70" to="0" repeatCount="indefinite" />
                        </circle>
                    </g>
                </svg>
            </div>
        </div>
    </div>
</asp:Content>
