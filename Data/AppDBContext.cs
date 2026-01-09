using MagicVilla_VillaAPI.Models;
using Microsoft.EntityFrameworkCore;
namespace MagicVilla_VillaAPI.Data
{
    public class AppDBContext : DbContext
    {

        //config thr EF to the .net app
        public  AppDBContext(DbContextOptions<AppDBContext> options) : base(options) { }



        public DbSet<Villa> Villas { get; set; }
        //Villas here is the name that will be given to sql server

    }
}
