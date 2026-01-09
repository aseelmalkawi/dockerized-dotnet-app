using System.ComponentModel.DataAnnotations;

namespace MagicVilla_VillaAPI.Models.Dto
{
    public class VillaUpdateDTO
    {
        [Required]
        public int Id { get; set; }
        [Required]
        [MaxLength(15)]
        public string Name { get; set; }
        public string Location { get; set; }
        public float sqft { get; set; }
        [Required]
        public string Details { get; set; }
        [Required]
        [Range(0, 5)]
        public double Rate { get; set; }
        [Required ]
        public string ImageUrl { get; set; }
        public DateTime CreatedDate { get; set; }

        public DateTime UpdatedDate { get; set; }

        public VillaUpdateDTO()
        {
            UpdatedDate = DateTime.Now;
        }

    }
}
