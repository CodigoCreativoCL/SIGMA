using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SitioBase.Model
{
    [Serializable]
    public class ArchivoBinario
    {

        public int abi_id { get; set; }
        public byte[] abi_archivo_binario { get; set; }

    }
}
