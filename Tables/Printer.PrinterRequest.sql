CREATE TABLE [Printer].[PrinterRequest]
(
[Id_PrinterRequest] [int] NOT NULL IDENTITY(1, 1),
[Id_Stampante] [int] NOT NULL,
[TemplateName] [varchar] (max) COLLATE Latin1_General_CI_AS NOT NULL,
[JsonString] [varchar] (max) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Tipo_Stato_Messaggio] [int] NOT NULL,
[Descrizione_Esecuzione] [varchar] (max) COLLATE Latin1_General_CI_AS NULL,
[Data_Esecuzione] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [Printer].[PrinterRequest] ADD CONSTRAINT [PK_PrinterRequest] PRIMARY KEY CLUSTERED ([Id_PrinterRequest]) ON [PRIMARY]
GO
